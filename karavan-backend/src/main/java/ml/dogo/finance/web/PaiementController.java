package ml.dogo.finance.web;

import java.util.List;
import java.util.Map;
import ml.dogo.finance.application.CallbackService;
import ml.dogo.finance.application.PaiementService;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class PaiementController {

    public record PaiementRequete(Long moyenPaiementId, Boolean utiliserPortefeuille) {
    }

    private final PaiementService paiements;
    private final CallbackService callbacks;

    public PaiementController(PaiementService paiements, CallbackService callbacks) {
        this.paiements = paiements;
        this.callbacks = callbacks;
    }

    /** L'en-tête Idempotency-Key est obligatoire : rejouer la requête ne débite jamais deux fois (RG-34). */
    @PostMapping("/participations/{id}/paiement")
    @PreAuthorize("hasAuthority('PAIEMENT_EFFECTUER')")
    public PaiementService.PaiementVue payer(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id,
                                             @RequestHeader("Idempotency-Key") String cle,
                                             @RequestBody(required = false) PaiementRequete r) {
        return paiements.initier(moi.id(), id, r == null ? null : r.moyenPaiementId(),
                r != null && Boolean.TRUE.equals(r.utiliserPortefeuille()), cle);
    }

    @GetMapping("/participations/{id}/paiements")
    @PreAuthorize("hasAuthority('PAIEMENT_EFFECTUER')")
    public List<PaiementService.PaiementVue> paiements(@AuthenticationPrincipal UtilisateurCourant moi,
                                                       @PathVariable long id) {
        return paiements.deLaParticipation(moi.id(), id);
    }

    /** Appelé par l'opérateur Mobile Money ; protégé par la signature HMAC de X-Signature, pas par un jeton (RG-35). */
    @PostMapping("/paiements/callback")
    public Map<String, String> callback(@RequestBody String corps,
                                        @RequestHeader(value = "X-Signature", required = false) String signature) {
        return Map.of("resultat", callbacks.traiter(corps, signature).name());
    }
}
