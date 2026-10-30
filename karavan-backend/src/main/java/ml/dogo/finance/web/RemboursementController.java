package ml.dogo.finance.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import ml.dogo.finance.application.RemboursementService;
import ml.dogo.finance.domain.MotifRemboursement;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Traitement des remboursements par un administrateur FINANCE (RG-60). */
@RestController
@RequestMapping("/api")
public class RemboursementController {

    public record DemandeRequete(@NotNull MotifRemboursement motif) {
    }

    public record RejetRequete(@NotBlank String justification) {
    }

    private final RemboursementService remboursements;

    public RemboursementController(RemboursementService remboursements) {
        this.remboursements = remboursements;
    }

    @GetMapping("/admin/remboursements")
    @PreAuthorize("hasAuthority('REMBOURSEMENT_APPROUVER')")
    public List<RemboursementService.RemboursementVue> enAttente() {
        return remboursements.enAttente();
    }

    @PostMapping("/admin/paiements/{paiementId}/remboursements")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('REMBOURSEMENT_APPROUVER')")
    public RemboursementService.RemboursementVue demander(@AuthenticationPrincipal UtilisateurCourant moi,
                                                          @PathVariable long paiementId,
                                                          @Valid @RequestBody DemandeRequete r) {
        return remboursements.demanderManuellement(moi.id(), paiementId, r.motif());
    }

    @PostMapping("/admin/remboursements/{id}/approbation")
    @PreAuthorize("hasAuthority('REMBOURSEMENT_APPROUVER')")
    public RemboursementService.RemboursementVue approuver(@AuthenticationPrincipal UtilisateurCourant moi,
                                                           @PathVariable long id) {
        return remboursements.approuver(moi.id(), id);
    }

    @PostMapping("/admin/remboursements/{id}/rejet")
    @PreAuthorize("hasAuthority('REMBOURSEMENT_APPROUVER')")
    public RemboursementService.RemboursementVue rejeter(@AuthenticationPrincipal UtilisateurCourant moi,
                                                         @PathVariable long id, @Valid @RequestBody RejetRequete r) {
        return remboursements.rejeter(moi.id(), id, r.justification());
    }

    @GetMapping("/moi/remboursements")
    @PreAuthorize("hasAnyAuthority('PARTICIPATION_GERER', 'ADMIN_CREER', 'REMBOURSEMENT_APPROUVER')")
    public List<RemboursementService.RemboursementVue> mesRemboursements(@AuthenticationPrincipal UtilisateurCourant moi) {
        return remboursements.pourCommercant(moi.id());
    }
}
