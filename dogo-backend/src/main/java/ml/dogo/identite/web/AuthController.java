package ml.dogo.identite.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import ml.dogo.identite.application.AuthService;
import ml.dogo.identite.application.InscriptionService;
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
            @NotNull TypeActeur type, @NotBlank String telephone, @NotBlank String nom, @NotBlank String pin,
            String nomBoutique, String adresseLivraison, String quartierBamako, String canalVente,
            String nomBoutiqueMarche, String numeroNif, String registreCommerce,
            String nomSocieteImport, String licenceTransit, String adresseDepot) {

        InscriptionService.Demande versDemande() {
            return new InscriptionService.Demande(type, telephone, nom, pin, nomBoutique, adresseLivraison,
                    quartierBamako, canalVente, nomBoutiqueMarche, numeroNif, registreCommerce, nomSocieteImport,
                    licenceTransit, adresseDepot);
        }
    }

    public record TelephoneRequete(@NotBlank String telephone) {
    }

    public record OtpRequete(@NotBlank String telephone, @NotBlank String code) {
    }

    public record ConnexionRequete(@NotBlank String telephone, @NotBlank String pin, String deviceId) {
    }

    private final InscriptionService inscription;
    private final AuthService auth;

    public AuthController(InscriptionService inscription, AuthService auth) {
        this.inscription = inscription;
        this.auth = auth;
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
    public AuthService.Connexion connecter(@Valid @RequestBody ConnexionRequete r, HttpServletRequest http) {
        return auth.connecter(r.telephone(), r.pin(), r.deviceId(), http.getRemoteAddr());
    }
}
