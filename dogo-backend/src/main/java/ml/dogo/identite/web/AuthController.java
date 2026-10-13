package ml.dogo.identite.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import ml.dogo.identite.application.AuthService;
import ml.dogo.identite.application.InscriptionService;
import ml.dogo.identite.application.RefreshTokenService;
import ml.dogo.identite.domain.TypeActeur;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Points d'entrée publics : création de compte, vérification du téléphone, connexion. */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    public record InscriptionRequete(
            @NotNull TypeActeur type, @NotBlank String telephone, @NotBlank String nom,
            String motDePasse, String pin,
            String nomBoutique, String adresseLivraison, String quartierBamako, String canalVente,
            String nomBoutiqueMarche, String numeroNif, String registreCommerce,
            String nomSocieteImport, String licenceTransit, String adresseDepot) {

        public String motDePasseEffectif() {
            return motDePasse != null && !motDePasse.isBlank() ? motDePasse : pin;
        }

        InscriptionService.Demande versDemande() {
            return new InscriptionService.Demande(type, telephone, nom, motDePasseEffectif(), nomBoutique, adresseLivraison,
                    quartierBamako, canalVente, nomBoutiqueMarche, numeroNif, registreCommerce, nomSocieteImport,
                    licenceTransit, adresseDepot);
        }
    }

    public record TelephoneRequete(@NotBlank String telephone) {
    }

    public record OtpRequete(@NotBlank String telephone, @NotBlank String code) {
    }

    public record ConnexionRequete(@NotBlank String telephone, String motDePasse, String pin, String deviceId) {
        public String motDePasseEffectif() {
            return motDePasse != null && !motDePasse.isBlank() ? motDePasse : pin;
        }
    }

    public record RefreshRequete(String refreshToken, String deviceId) {
    }

    private static final String COOKIE_NAME = "dogo_refresh_token";

    private final InscriptionService inscription;
    private final AuthService auth;
    private final RefreshTokenService refreshTokenService;

    public AuthController(InscriptionService inscription, AuthService auth, RefreshTokenService refreshTokenService) {
        this.inscription = inscription;
        this.auth = auth;
        this.refreshTokenService = refreshTokenService;
    }

    @PostMapping("/inscription")
    @ResponseStatus(HttpStatus.CREATED)
    public InscriptionService.Resultat inscrire(@Valid @RequestBody InscriptionRequete r) {
        return inscription.inscrire(r.versDemande());
    }

    @PostMapping("/renvoyer-otp")
    public InscriptionService.Resultat renvoyerOtp(@Valid @RequestBody TelephoneRequete r) {
        return inscription.renvoyerOtp(r.telephone());
    }

    @PostMapping("/verifier-otp")
    public InscriptionService.Resultat verifierOtp(@Valid @RequestBody OtpRequete r) {
        return inscription.verifierOtp(r.telephone(), r.code());
    }

    @PostMapping("/connexion")
    public AuthService.Connexion connecter(@Valid @RequestBody ConnexionRequete r,
                                           HttpServletRequest http,
                                           jakarta.servlet.http.HttpServletResponse res) {
        AuthService.Connexion c = auth.connecter(r.telephone(), r.motDePasseEffectif(), r.deviceId(), http.getRemoteAddr());
        if (c.refreshToken() != null && c.refreshExpiration() != null) {
            poserCookie(res, c.refreshToken(), http.isSecure(), c.refreshExpiration());
        }
        return c;
    }

    @PostMapping("/refresh")
    public org.springframework.http.ResponseEntity<RefreshTokenService.TokenPair> rafraichir(
            @RequestBody(required = false) RefreshRequete r,
            HttpServletRequest request,
            jakarta.servlet.http.HttpServletResponse response) {
        String token = extraireRefreshToken(r != null ? r.refreshToken() : null, request);
        if (token == null || token.isBlank()) {
            throw new ml.dogo.shared.errors.ErreurMetier(ml.dogo.shared.errors.CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Jeton de rafraîchissement absent");
        }
        String deviceId = (r != null && r.deviceId() != null && !r.deviceId().isBlank())
                ? r.deviceId()
                : request.getHeader("X-Device-Id");

        RefreshTokenService.TokenPair pair = refreshTokenService.rafraichir(token, deviceId, request.getRemoteAddr());
        poserCookie(response, pair.refreshToken(), request.isSecure(), pair.refreshExpiration());
        return org.springframework.http.ResponseEntity.ok(pair);
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(
            @RequestBody(required = false) RefreshRequete r,
            HttpServletRequest request,
            jakarta.servlet.http.HttpServletResponse response) {
        String token = extraireRefreshToken(r != null ? r.refreshToken() : null, request);
        if (token != null && !token.isBlank()) {
            refreshTokenService.revoquerToken(token);
        }
        supprimerCookie(response, request.isSecure());
    }

    private String extraireRefreshToken(String fromBody, HttpServletRequest request) {
        if (fromBody != null && !fromBody.isBlank()) {
            return fromBody.trim();
        }
        if (request.getCookies() != null) {
            for (jakarta.servlet.http.Cookie c : request.getCookies()) {
                if (COOKIE_NAME.equals(c.getName()) && c.getValue() != null && !c.getValue().isBlank()) {
                    return c.getValue().trim();
                }
            }
        }
        return null;
    }

    private void poserCookie(jakarta.servlet.http.HttpServletResponse response, String token, boolean isSecure, java.time.Instant expiration) {
        long maxAge = Math.max(0, java.time.Duration.between(java.time.Instant.now(), expiration).toSeconds());
        org.springframework.http.ResponseCookie cookie = org.springframework.http.ResponseCookie.from(COOKIE_NAME, token)
                .httpOnly(true)
                .secure(isSecure)
                .path("/api")
                .sameSite("Lax")
                .maxAge(maxAge)
                .build();
        response.addHeader(org.springframework.http.HttpHeaders.SET_COOKIE, cookie.toString());
    }

    private void supprimerCookie(jakarta.servlet.http.HttpServletResponse response, boolean isSecure) {
        org.springframework.http.ResponseCookie cookie = org.springframework.http.ResponseCookie.from(COOKIE_NAME, "")
                .httpOnly(true)
                .secure(isSecure)
                .path("/api")
                .sameSite("Lax")
                .maxAge(0)
                .build();
        response.addHeader(org.springframework.http.HttpHeaders.SET_COOKIE, cookie.toString());
    }
}
