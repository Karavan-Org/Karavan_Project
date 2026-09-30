package ml.dogo.audit.web;

import java.util.List;
import ml.dogo.audit.application.AuditService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Consultation du journal d'audit (RG-66, RG-67) : lecture seule. */
@RestController
@RequestMapping("/api/admin/audit")
public class AuditController {

    private final AuditService audit;

    public AuditController(AuditService audit) {
        this.audit = audit;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('AUDIT_LIRE')")
    public List<AuditService.LigneAudit> dernieres(@RequestParam(defaultValue = "50") int taille) {
        return audit.dernieres(taille);
    }

    @GetMapping("/verification")
    @PreAuthorize("hasAuthority('AUDIT_LIRE')")
    public AuditService.ResultatVerification verifier() {
        return audit.verifierChaine();
    }
}
