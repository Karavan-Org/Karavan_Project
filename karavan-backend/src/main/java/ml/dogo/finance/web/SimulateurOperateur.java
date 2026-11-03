package ml.dogo.finance.web;

import java.util.Map;
import ml.dogo.finance.application.CallbackService;
import ml.dogo.finance.application.GenerateurCallbackDemo;
import ml.dogo.finance.application.TraitementPaiement;
import org.springframework.context.annotation.Profile;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Démonstration uniquement (profil « demo ») : joue le rôle de l'opérateur Mobile Money. Il fabrique un vrai callback,
 * le signe avec le secret partagé et le fait passer par le même chemin que celui d'un opérateur réel.
 */
@Profile({"demo", "local", "dev"})
@PreAuthorize("hasAnyAuthority('ADMIN_CREER', 'PAIEMENT_EFFECTUER')")
@RestController
@RequestMapping("/api/dev/mobile-money")
public class SimulateurOperateur {

    private final GenerateurCallbackDemo generateur;
    private final CallbackService callbacks;

    public SimulateurOperateur(GenerateurCallbackDemo generateur, CallbackService callbacks) {
        this.generateur = generateur;
        this.callbacks = callbacks;
    }

    @PostMapping("/{paiementId}/succes")
    @ResponseStatus(HttpStatus.OK)
    public Map<String, String> succes(@PathVariable long paiementId) {
        return jouer(paiementId, "SUCCES");
    }

    @PostMapping("/{paiementId}/echec")
    public Map<String, String> echec(@PathVariable long paiementId) {
        return jouer(paiementId, "ECHEC");
    }

    private Map<String, String> jouer(long paiementId, String statut) {
        String corps = generateur.construire(paiementId, statut);
        TraitementPaiement.Resultat resultat = callbacks.traiter(corps, callbacks.signer(corps));
        return Map.of("resultat", resultat.name(), "callback", corps);
    }
}
