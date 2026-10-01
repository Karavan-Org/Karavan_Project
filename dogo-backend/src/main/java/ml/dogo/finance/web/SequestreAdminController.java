package ml.dogo.finance.web;

import ml.dogo.finance.application.SequestreAdminService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoint d'administration et tableau de bord des séquestres (RG-36, RG-38, écran sequestre.svg).
 */
@RestController
@RequestMapping("/api/admin/finance")
public class SequestreAdminController {

    private final SequestreAdminService sequestres;

    public SequestreAdminController(SequestreAdminService sequestres) {
        this.sequestres = sequestres;
    }

    @GetMapping("/sequestres")
    @PreAuthorize("hasAnyAuthority('REMBOURSEMENT_APPROUVER', 'AUDIT_LIRE', 'PORTEFEUILLE_RETIRER')")
    public SequestreAdminService.SequestreDashboardVue dashboard() {
        return sequestres.dashboard();
    }
}
