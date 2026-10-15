package ml.dogo.identite.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.litige.persistence.Litige;
import ml.dogo.litige.persistence.LitigeRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Gestion du support client et partage d'informations entre administrateurs (Admin Support & Admin Technique).
 */
@RestController
@RequestMapping("/api/admin/support")
@Transactional
public class SupportAdminController {

    public record MessageUtilisateurRequete(@NotNull Long destinataireId, @NotBlank String message) {}
    public record DiffusionAdminsRequete(@NotBlank String sujet, @NotBlank String message) {}

    private final UtilisateurRepository utilisateurs;
    private final NotificationApi notifications;
    private final LitigeRepository litiges;
    private final AuditApi audit;

    public SupportAdminController(UtilisateurRepository utilisateurs, NotificationApi notifications,
                                  LitigeRepository litiges, AuditApi audit) {
        this.utilisateurs = utilisateurs;
        this.notifications = notifications;
        this.litiges = litiges;
        this.audit = audit;
    }

    @PostMapping("/message-utilisateur")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyAuthority('COMPTE_SUSPENDRE', 'ADMIN_CREER')")
    public void envoyerMessageUtilisateur(@AuthenticationPrincipal UtilisateurCourant moi,
                                          @Valid @RequestBody MessageUtilisateurRequete r) {
        String msg = "[Support Dɔgɔ] " + r.message();
        notifications.notifier(r.destinataireId(), msg);
        utilisateurs.findById(r.destinataireId()).ifPresent(u -> {
            if (u.getTelephone() != null && !u.getTelephone().isBlank()) {
                notifications.envoyerSms(u.getTelephone(), msg);
            }
        });
        audit.tracer(moi.id(), "SUPPORT_MESSAGE_ENVOYE", "utilisateur=" + r.destinataireId(), r.message());
    }

    @PostMapping("/diffuser-admins")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyAuthority('COMPTE_SUSPENDRE', 'ADMIN_CREER')")
    public void diffuserAdmins(@AuthenticationPrincipal UtilisateurCourant moi,
                               @Valid @RequestBody DiffusionAdminsRequete r) {
        String contenu = "[Note Support : " + r.sujet() + "] " + r.message();
        utilisateurs.findAll().stream()
                .filter(u -> u instanceof Administrateur)
                .forEach(admin -> notifications.notifier(admin.getId(), contenu));
        audit.tracer(moi.id(), "SUPPORT_NOTE_DIFFUSEE", "sujet=" + r.sujet(), r.message());
    }

    @GetMapping("/litiges")
    @PreAuthorize("hasAnyAuthority('COMPTE_SUSPENDRE', 'ADMIN_CREER', 'REMBOURSEMENT_APPROUVER')")
    public List<Litige> listerLitiges() {
        return litiges.findAll();
    }
}
