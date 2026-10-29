package ml.dogo.identite.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.constraints.NotBlank;
import java.time.Duration;
import java.time.Instant;
import ml.dogo.identite.application.Auth0AuthService;
import ml.dogo.identite.application.AuthService;
import ml.dogo.identite.domain.TypeActeur;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Contrôleur REST pour l'authentification et l'inscription via Auth0 OAuth2 / OIDC.
 * Points d'entrée :
 * - POST /api/auth/auth0 : vérification du jeton Auth0, connexion si sub connu, PROFIL_INCOMPLET sinon.
 * - POST /api/auth/auth0/demander-otp : déclenchement OTP SMS vers le numéro malien.
 * - POST /api/auth/auth0/completer : validation OTP + création/fusion de compte Karavan.
 */
@RestController
@RequestMapping("/api/auth/auth0")
public class Auth0AuthController {

    private static final String CLIENT_HEADER = "X-Client-Platform";
    private static final String CONSOLE_ADMIN = "admin-console";
    private static final String FLUTTER_WEB = "flutter-web";
    private static final String COOKIE_NAME = "karavan_refresh_token";

    @Value("${dogo.auth.cookie-secure:false}")
    private boolean cookiesSecurises;

    public record Auth0TokenRequete(@NotBlank String idToken, String deviceId) {
    }

    public record Auth0CompleterRequete(
            @NotBlank String jetonInscription,
            @NotBlank String telephone,
            String codeOtp,
            TypeActeur typeActeur,
            String nomBoutique,
            String quartierBamako,
            String deviceId
    ) {
    }

    private final Auth0AuthService auth0AuthService;

    public Auth0AuthController(Auth0AuthService auth0AuthService) {
        this.auth0AuthService = auth0AuthService;
    }

    @PostMapping
    public ResponseEntity<?> authentifier(@RequestBody Auth0TokenRequete r,
                                          HttpServletRequest request,
                                          HttpServletResponse response) {
        String deviceId = r.deviceId() != null && !r.deviceId().isBlank()
                ? r.deviceId()
                : request.getHeader("X-Device-Id");

        Auth0AuthService.ResultatAuth0 resultat = auth0AuthService.authentifier(
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
    public Auth0AuthService.ReponseOtpAuth0 demanderOtp(@RequestBody Auth0CompleterRequete r,
                                                         HttpServletRequest request) {
        return auth0AuthService.declencherOtpCompleter(r.jetonInscription(), r.telephone(), request.getRemoteAddr());
    }

    @PostMapping("/completer")
    public ResponseEntity<?> completer(@RequestBody Auth0CompleterRequete r,
                                       HttpServletRequest request,
                                       HttpServletResponse response) {
        // Si le code OTP n'est pas encore fourni, on déclenche l'envoi de l'OTP
        if (r.codeOtp() == null || r.codeOtp().isBlank()) {
            Auth0AuthService.ReponseOtpAuth0 reponseOtp = auth0AuthService.declencherOtpCompleter(
                    r.jetonInscription(), r.telephone(), request.getRemoteAddr());
            return ResponseEntity.ok(reponseOtp);
        }

        // Si le code OTP est fourni, on valide l'OTP, crée/fusionne le compte et ouvre la session
        String deviceId = r.deviceId() != null && !r.deviceId().isBlank()
                ? r.deviceId()
                : request.getHeader("X-Device-Id");

        Auth0AuthService.DemandeCompleterAuth0 demande = new Auth0AuthService.DemandeCompleterAuth0(
                r.jetonInscription(),
                r.telephone(),
                r.codeOtp(),
                r.typeActeur(),
                r.nomBoutique(),
                r.quartierBamako(),
                deviceId
        );

        AuthService.Connexion c = auth0AuthService.completerEtConnecter(demande, request.getRemoteAddr());
        poserCookie(response, c.refreshToken(), cookieSecurise(request), c.refreshExpiration());

        AuthController.ReponseSession reponseSession = formaterReponseSession(
                c.jeton(), c.refreshToken(), c.expiration(), c.refreshExpiration(), c.profil(), request);
        return ResponseEntity.ok(reponseSession);
    }

    private boolean cookieSecurise(HttpServletRequest request) {
        return cookiesSecurises || request.isSecure() || "https".equalsIgnoreCase(request.getHeader("X-Forwarded-Proto"));
    }

    private void poserCookie(HttpServletResponse response, String refreshToken, boolean secure, Instant expiration) {
        long ageMax = Math.max(0, Duration.between(Instant.now(), expiration).getSeconds());
        org.springframework.http.ResponseCookie cookie = org.springframework.http.ResponseCookie.from(COOKIE_NAME, refreshToken)
                .httpOnly(true)
                .secure(secure)
                .sameSite("Lax")
                .path("/api/auth")
                .maxAge(ageMax)
                .build();
        response.addHeader(org.springframework.http.HttpHeaders.SET_COOKIE, cookie.toString());
    }

    private AuthController.ReponseSession formaterReponseSession(String jeton,
                                                                 String refreshToken,
                                                                 Instant expiration,
                                                                 Instant refreshExpiration,
                                                                 AuthService.Profil profil,
                                                                 HttpServletRequest request) {
        String clientPlatform = request.getHeader(CLIENT_HEADER);
        boolean estConsoleAdmin = CONSOLE_ADMIN.equalsIgnoreCase(clientPlatform);
        boolean estFlutterWeb = FLUTTER_WEB.equalsIgnoreCase(clientPlatform);

        String refreshDansCorps = (estConsoleAdmin || estFlutterWeb) ? refreshToken : null;

        return new AuthController.ReponseSession(
                jeton,
                refreshDansCorps,
                expiration,
                refreshExpiration,
                profil
        );
    }
}
