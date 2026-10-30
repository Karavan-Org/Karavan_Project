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

    @Value("${dogo.auth.cookie-secure:false}")
    private boolean cookiesSecurises;

    public record GoogleTokenRequete(
            @NotBlank String idToken,
            String deviceId,
            TypeActeur typeActeur,
            GoogleAuthService.ModeAuthGoogle mode
    ) {
        public GoogleTokenRequete(String idToken, String deviceId) {
            this(idToken, deviceId, null, null);
        }

        public GoogleTokenRequete(String idToken, String deviceId, TypeActeur typeActeur) {
            this(idToken, deviceId, typeActeur, null);
        }
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

        GoogleAuthService.ResultatAuthGoogle resultat;
        if (r.mode() != null) {
            resultat = googleAuthService.authentifier(r.idToken(), deviceId, request.getRemoteAddr(), r.typeActeur(), r.mode());
        } else if (r.typeActeur() != null) {
            resultat = googleAuthService.authentifier(r.idToken(), deviceId, request.getRemoteAddr(), r.typeActeur());
        } else {
            resultat = googleAuthService.authentifier(r.idToken(), deviceId, request.getRemoteAddr());
        }

        if ("CONNECTE".equals(resultat.statut())) {
            if (resultat.refreshToken() != null && resultat.refreshExpiration() != null) {
                CookieSessionWebHelper.poserCookie(
                        request,
                        response,
                        resultat.refreshToken(),
                        CookieSessionWebHelper.cookieSecurise(request, cookiesSecurises),
                        resultat.refreshExpiration());
            }
            AuthController.ReponseSession reponseSession = CookieSessionWebHelper.formaterReponseSession(
                    resultat.jeton(), resultat.refreshToken(), resultat.expiration(),
                    resultat.refreshExpiration(), resultat.profil(), request);
            return ResponseEntity.ok(reponseSession);
        }

        return ResponseEntity.ok(resultat);
    }

    @PostMapping("/demander-otp")
    public GoogleAuthService.ReponseOtpGoogle demanderOtp(@RequestBody GoogleCompleterRequete r,
                                                          HttpServletRequest request) {
        return r.typeActeur() != null
                ? googleAuthService.declencherOtpCompleter(r.jetonInscription(), r.telephone(), r.typeActeur(), request.getRemoteAddr())
                : googleAuthService.declencherOtpCompleter(r.jetonInscription(), r.telephone(), request.getRemoteAddr());
    }

    @PostMapping("/completer")
    public ResponseEntity<?> completer(@RequestBody GoogleCompleterRequete r,
                                       HttpServletRequest request,
                                       HttpServletResponse response) {
        // Si le code OTP n'est pas encore fourni, on déclenche l'envoi de l'OTP
        if (r.codeOtp() == null || r.codeOtp().isBlank()) {
            GoogleAuthService.ReponseOtpGoogle reponseOtp = r.typeActeur() != null
                    ? googleAuthService.declencherOtpCompleter(r.jetonInscription(), r.telephone(), r.typeActeur(), request.getRemoteAddr())
                    : googleAuthService.declencherOtpCompleter(r.jetonInscription(), r.telephone(), request.getRemoteAddr());
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
            CookieSessionWebHelper.poserCookie(
                    request,
                    response,
                    c.refreshToken(),
                    CookieSessionWebHelper.cookieSecurise(request, cookiesSecurises),
                    c.refreshExpiration());
        }

        AuthController.ReponseSession reponseSession = CookieSessionWebHelper.formaterReponseSession(
                c.jeton(), c.refreshToken(), c.expiration(), c.refreshExpiration(), c.profil(), request);
        return ResponseEntity.ok(reponseSession);
    }
}

