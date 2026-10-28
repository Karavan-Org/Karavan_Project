package ml.dogo.identite.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.constraints.NotBlank;
import java.time.Duration;
import java.time.Instant;
import ml.dogo.identite.application.AuthService;
import ml.dogo.identite.application.GoogleAuthService;
import ml.dogo.identite.domain.TypeActeur;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Contrôleur REST pour l'authentification et l'inscription via Google OAuth2.
 * Points d'entrée :
 * - POST /api/auth/google : vérification de l'ID token, connexion si sub connu, PROFIL_INCOMPLET sinon.
 * - POST /api/auth/google/completer : déclenchement OTP SMS ou validation OTP + création/fusion de compte.
 */
@RestController
@RequestMapping("/api/auth/google")
public class GoogleAuthController {

    private static final String CLIENT_HEADER = "X-Client-Platform";
    private static final String CONSOLE_ADMIN = "admin-console";
    private static final String FLUTTER_WEB = "flutter-web";
    private static final String COOKIE_NAME = "dogo_refresh_token";

    @Value("${dogo.auth.cookie-secure:false}")
    private boolean cookiesSecurises;

    public record GoogleTokenRequete(@NotBlank String idToken, String deviceId) {
    }

    public record GoogleCompleterRequete(
            @NotBlank String jetonInscription,
            @NotBlank String telephone,
            String codeOtp,
            TypeActeur typeActeur,
            String nomBoutique,
            String quartierBamako,
            String deviceId
    ) {
    }

    private final GoogleAuthService googleAuthService;

    public GoogleAuthController(GoogleAuthService googleAuthService) {
        this.googleAuthService = googleAuthService;
    }

    @PostMapping
    public ResponseEntity<?> authentifier(@RequestBody GoogleTokenRequete r,
                                          HttpServletRequest request,
                                          HttpServletResponse response) {
        String deviceId = r.deviceId() != null && !r.deviceId().isBlank()
                ? r.deviceId()
                : request.getHeader("X-Device-Id");

        GoogleAuthService.ResultatAuthGoogle resultat = googleAuthService.authentifier(
                r.idToken(), deviceId, request.getRemoteAddr());

        if ("CONNECTE".equals(resultat.statut())) {
            if (resultat.refreshToken() != null && resultat.refreshExpiration() != null) {
                poserCookie(response, resultat.refreshToken(), cookieSecurise(request), resultat.refreshExpiration());
            }
            AuthController.ReponseSession reponseSession = formaterReponseSession(
                    resultat.jeton(), resultat.refreshToken(), resultat.expiration(),
                    resultat.refreshExpiration(), resultat.profil(), request);
            return ResponseEntity.ok(reponseSession);
        }

        return ResponseEntity.ok(resultat);
    }

    @PostMapping("/demander-otp")
    public GoogleAuthService.ReponseOtpGoogle demanderOtp(@RequestBody GoogleCompleterRequete r,
                                                          HttpServletRequest request) {
        return googleAuthService.declencherOtpCompleter(r.jetonInscription(), r.telephone(), request.getRemoteAddr());
    }

    @PostMapping("/completer")
    public ResponseEntity<?> completer(@RequestBody GoogleCompleterRequete r,
                                       HttpServletRequest request,
                                       HttpServletResponse response) {
        // Si le code OTP n'est pas encore fourni, on déclenche l'envoi de l'OTP
        if (r.codeOtp() == null || r.codeOtp().isBlank()) {
            GoogleAuthService.ReponseOtpGoogle reponseOtp = googleAuthService.declencherOtpCompleter(
                    r.jetonInscription(), r.telephone(), request.getRemoteAddr());
            return ResponseEntity.ok(reponseOtp);
        }

        // Si le code OTP est fourni, on valide l'OTP, crée/fusionne le compte et ouvre la session
        String deviceId = r.deviceId() != null && !r.deviceId().isBlank()
                ? r.deviceId()
                : request.getHeader("X-Device-Id");

        GoogleAuthService.DemandeCompleterGoogle demande = new GoogleAuthService.DemandeCompleterGoogle(
                r.jetonInscription(), r.telephone(), r.codeOtp(), r.typeActeur(),
                r.nomBoutique(), r.quartierBamako(), deviceId);

        AuthService.Connexion c = googleAuthService.completerEtConnecter(demande, request.getRemoteAddr());

        if (c.refreshToken() != null && c.refreshExpiration() != null) {
            poserCookie(response, c.refreshToken(), cookieSecurise(request), c.refreshExpiration());
        }

        AuthController.ReponseSession reponseSession = formaterReponseSession(
                c.jeton(), c.refreshToken(), c.expiration(), c.refreshExpiration(), c.profil(), request);
        return ResponseEntity.ok(reponseSession);
    }

    private AuthController.ReponseSession formaterReponseSession(String jeton, String refreshToken,
                                                                 Instant expiration, Instant refreshExpiration,
                                                                 AuthService.Profil profil,
                                                                 HttpServletRequest request) {
        String client = request.getHeader(CLIENT_HEADER);
        boolean exposeRefreshToken = !CONSOLE_ADMIN.equalsIgnoreCase(client)
                && !FLUTTER_WEB.equalsIgnoreCase(client);
        return new AuthController.ReponseSession(
                jeton,
                exposeRefreshToken ? refreshToken : null,
                expiration,
                exposeRefreshToken ? refreshExpiration : null,
                profil);
    }

    private boolean cookieSecurise(HttpServletRequest request) {
        return request.isSecure() || cookiesSecurises;
    }

    private void poserCookie(HttpServletResponse response, String token, boolean isSecure, Instant expiration) {
        long maxAge = Math.max(0, Duration.between(Instant.now(), expiration).toSeconds());
        org.springframework.http.ResponseCookie cookie = org.springframework.http.ResponseCookie.from(COOKIE_NAME, token)
                .httpOnly(true)
                .secure(isSecure)
                .path("/api")
                .sameSite("Lax")
                .maxAge(maxAge)
                .build();
        response.addHeader(org.springframework.http.HttpHeaders.SET_COOKIE, cookie.toString());
    }
}

