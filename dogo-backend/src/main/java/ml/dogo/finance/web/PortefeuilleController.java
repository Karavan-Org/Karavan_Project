package ml.dogo.finance.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;
import java.util.List;
import ml.dogo.finance.application.PortefeuilleService;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/moi/portefeuille")
public class PortefeuilleController {

    public record RetraitRequete(@NotNull @Positive BigDecimal montant, Long moyenPaiementId) {
    }

    public record RechargeRequete(@NotNull @Positive BigDecimal montant, String operateur, String numeroTelephone) {
    }

    private final PortefeuilleService portefeuille;

    public PortefeuilleController(PortefeuilleService portefeuille) {
        this.portefeuille = portefeuille;
    }

    @GetMapping
    @PreAuthorize("isAuthenticated()")
    public PortefeuilleService.PortefeuilleVue voir(@AuthenticationPrincipal UtilisateurCourant moi) {
        return portefeuille.voir(moi.id());
    }

    @GetMapping("/mouvements")
    @PreAuthorize("isAuthenticated()")
    public List<PortefeuilleService.MouvementVue> mouvements(@AuthenticationPrincipal UtilisateurCourant moi,
                                                             @RequestParam(defaultValue = "50") int taille) {
        return portefeuille.mouvements(moi.id(), taille);
    }

    @PostMapping("/recharge")
    @PreAuthorize("isAuthenticated()")
    public PortefeuilleService.PortefeuilleVue recharger(@AuthenticationPrincipal UtilisateurCourant moi,
                                                         @Valid @RequestBody RechargeRequete r) {
        return portefeuille.recharger(moi.id(), r.montant(), r.operateur(), r.numeroTelephone());
    }

    @PostMapping("/retraits")
    @PreAuthorize("hasAuthority('PORTEFEUILLE_RETIRER')")
    public PortefeuilleService.PortefeuilleVue retirer(@AuthenticationPrincipal UtilisateurCourant moi,
                                                       @RequestHeader("Idempotency-Key") String cle,
                                                       @Valid @RequestBody RetraitRequete r) {
        return portefeuille.retirer(moi.id(), r.montant(), r.moyenPaiementId(), cle);
    }
}
