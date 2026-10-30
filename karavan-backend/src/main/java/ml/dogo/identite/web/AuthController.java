package ml.dogo.identite.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import ml.dogo.identite.application.AuthService;
import ml.dogo.identite.application.InscriptionService;
import ml.dogo.identite.application.RefreshTokenService;
import ml.dogo.identite.domain.TypeActeur;
import org.springframework.beans.factory.annotation.Value;
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

    @Value("${dogo.auth.cookie-secure:false}")
    private boolean cookiesSecurises;

    public record ReponseSession(String jeton, String refreshToken, Instant expiration,
                                 Instant refreshExpiration, AuthService.Profil profil) {
    }

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

    public record ConnexionRequete(@NotBlank String telephone, String motDePasse, String pin, String deviceId, TypeActeur typeActeur) {
        public ConnexionRequete(String telephone, String motDePasse, String pin, String deviceId) {
            this(telephone, motDePasse, pin, deviceId, null);
        }

        public String motDePasseEffectif() {
            return motDePasse != null && !motDePasse.isBlank() ? motDePasse : pin;
        }
    }

    public record RefreshRequete(String refreshToken, String deviceId) {
    }

    public record DemandeResetMdpRequete(@NotBlank String telephone, TypeActeur typeActeur) {
        public DemandeResetMdpRequete(String telephone) {
            this(telephone, null);
        }
    }

    public record ReinitialiserMdpRequete(@NotBlank String telephone, @NotBlank String code, @NotBlank String nouveauMotDePasse, TypeActeur typeActeur) {
        public ReinitialiserMdpRequete(String telephone, String code, String nouveauMotDePasse) {
            this(telephone, code, nouveauMotDePasse, null);
        }
    }

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

    @PostMapping("/mot-de-passe-oublie/demande")
    public InscriptionService.Resultat demanderReinitialisationMotDePasse(@Valid @RequestBody DemandeResetMdpRequete r) {
        return r.typeActeur() != null
                ? auth.demanderReinitialisationMotDePasse(r.telephone(), r.typeActeur())
                : auth.demanderReinitialisationMotDePasse(r.telephone());
    }

    @PostMapping("/mot-de-passe-oublie/reinitialiser")
    public java.util.Map<String, String> reinitialiserMotDePasse(@Valid @RequestBody ReinitialiserMdpRequete r) {
        if (r.typeActeur() != null) {
            auth.reinitialiserMotDePasseParOtp(r.telephone(), r.code(), r.nouveauMotDePasse(), r.typeActeur());
        } else {
            auth.reinitialiserMotDePasseParOtp(r.telephone(), r.code(), r.nouveauMotDePasse());
        }
        return java.util.Map.of("message", "Votre mot de passe a été réinitialisé avec succès.");
    }

    @PostMapping("/connexion")
    public ReponseSession connecter(@Valid @RequestBody ConnexionRequete r,
                                    HttpServletRequest http,
                                    jakarta.servlet.http.HttpServletResponse res) {
        AuthService.Connexion c = r.typeActeur() != null
                ? auth.connecter(r.telephone(), r.motDePasseEffectif(), r.deviceId(), http.getRemoteAddr(), r.typeActeur())
                : auth.connecter(r.telephone(), r.motDePasseEffectif(), r.deviceId(), http.getRemoteAddr());
        if (c.refreshToken() != null && c.refreshExpiration() != null) {
            CookieSessionWebHelper.poserCookie(
                    http,
                    res,
                    c.refreshToken(),
                    CookieSessionWebHelper.cookieSecurise(http, cookiesSecurises),
                    c.refreshExpiration());
        }
        return CookieSessionWebHelper.formaterReponseSession(
                c.jeton(), c.refreshToken(), c.expiration(), c.refreshExpiration(), c.profil(), http);
    }

    @PostMapping("/refresh")
    public org.springframework.http.ResponseEntity<ReponseSession> rafraichir(
            @RequestBody(required = false) RefreshRequete r,
            HttpServletRequest request,
            jakarta.servlet.http.HttpServletResponse response) {
        String token = CookieSessionWebHelper.extraireRefreshToken(r != null ? r.refreshToken() : null, request);
        if (token == null || token.isBlank()) {
            throw new ml.dogo.shared.errors.ErreurMetier(ml.dogo.shared.errors.CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Jeton de rafraîchissement absent");
        }
        String deviceId = (r != null && r.deviceId() != null && !r.deviceId().isBlank())
                ? r.deviceId()
                : request.getHeader("X-Device-Id");

        RefreshTokenService.TokenPair pair = refreshTokenService.rafraichir(token, deviceId, request.getRemoteAddr());
        CookieSessionWebHelper.poserCookie(
                request,
                response,
                pair.refreshToken(),
                CookieSessionWebHelper.cookieSecurise(request, cookiesSecurises),
                pair.refreshExpiration());
        return org.springframework.http.ResponseEntity.ok(CookieSessionWebHelper.formaterReponseSession(
                pair.jeton(), pair.refreshToken(), pair.expiration(), pair.refreshExpiration(), pair.profil(), request));
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(
            @RequestBody(required = false) RefreshRequete r,
            HttpServletRequest request,
            jakarta.servlet.http.HttpServletResponse response) {
        String token = CookieSessionWebHelper.extraireRefreshToken(r != null ? r.refreshToken() : null, request);
        if (token != null && !token.isBlank()) {
            refreshTokenService.revoquerToken(token);
        }
        CookieSessionWebHelper.supprimerCookie(
                request,
                response,
                CookieSessionWebHelper.cookieSecurise(request, cookiesSecurises));
    }
}
