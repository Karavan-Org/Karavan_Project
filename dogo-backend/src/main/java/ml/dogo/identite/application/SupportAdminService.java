package ml.dogo.identite.application;

import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.litige.api.LitigeApi;
import ml.dogo.notification.api.NotificationApi;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Cas d'usage du support administratif. */
@Service
@Transactional
public class SupportAdminService {

    private final UtilisateurRepository utilisateurs;
    private final NotificationApi notifications;
    private final LitigeApi litiges;
    private final AuditApi audit;

    public SupportAdminService(UtilisateurRepository utilisateurs, NotificationApi notifications,
                               LitigeApi litiges, AuditApi audit) {
        this.utilisateurs = utilisateurs;
        this.notifications = notifications;
        this.litiges = litiges;
        this.audit = audit;
    }

    public void envoyerMessageUtilisateur(long administrateurId, long destinataireId, String message) {
        String contenu = "[Support DoGo] " + message;
        notifications.notifier(destinataireId, contenu);
        utilisateurs.findById(destinataireId).ifPresent(utilisateur -> {
            if (utilisateur.getTelephone() != null && !utilisateur.getTelephone().isBlank()) {
                notifications.envoyerSms(utilisateur.getTelephone(), contenu);
            }
        });
        audit.tracer(administrateurId, "SUPPORT_MESSAGE_ENVOYE", "utilisateur=" + destinataireId, message);
    }

    public void diffuserAdmins(long administrateurId, String sujet, String message) {
        String contenu = "[Note Support : " + sujet + "] " + message;
        utilisateurs.findAll().stream()
                .filter(Administrateur.class::isInstance)
                .forEach(admin -> notifications.notifier(admin.getId(), contenu));
        audit.tracer(administrateurId, "SUPPORT_NOTE_DIFFUSEE", "sujet=" + sujet, message);
    }

    @Transactional(readOnly = true)
    public List<LitigeApi.LitigeInfo> listerLitiges() {
        return litiges.lister();
    }
}
