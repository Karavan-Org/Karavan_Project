package ml.dogo.notification.application;

import java.time.Clock;
import java.util.List;
import java.time.Instant;
import ml.dogo.notification.api.AnnuaireTelephones;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.notification.domain.StatutNotification;
import ml.dogo.notification.persistence.Notification;
import ml.dogo.notification.persistence.NotificationRepository;
import ml.dogo.shared.errors.ErreurMetier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Notifications SMS (RG-69). L'envoi a lieu après le commit de l'opération métier qui le demande, dans sa propre
 * transaction, et ne remonte jamais d'exception à l'appelant (RG-70).
 */
@Service
public class NotificationService implements NotificationApi {

    static final int MAX_TENTATIVES = 3;

    private static final Logger LOG = LoggerFactory.getLogger(NotificationService.class);

    private final NotificationRepository notifications;
    private final PasserelleSms sms;
    private final AnnuaireTelephones annuaire;
    private final Clock horloge;
    private final TransactionTemplate transactionIndependante;

    public NotificationService(NotificationRepository notifications, PasserelleSms sms, AnnuaireTelephones annuaire,
                               Clock horloge, PlatformTransactionManager gestionnaire) {
        this.notifications = notifications;
        this.sms = sms;
        this.annuaire = annuaire;
        this.horloge = horloge;
        this.transactionIndependante = new TransactionTemplate(gestionnaire);
        this.transactionIndependante.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    @Override
    public void notifier(long utilisateurId, String contenu) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    envoyerEtEnregistrer(utilisateurId, contenu);
                }
            });
        } else {
            envoyerEtEnregistrer(utilisateurId, contenu);
        }
    }

    @Override
    public void envoyerSms(String telephone, String message) {
        try {
            if (!sms.envoyer(telephone, message)) {
                LOG.warn("SMS refusé par la passerelle pour {}", telephone);
            }
        } catch (RuntimeException e) {
            LOG.warn("Échec d'envoi de SMS pour {}", telephone, e);
        }
    }

    private void envoyerEtEnregistrer(long utilisateurId, String contenu) {
        try {
            transactionIndependante.executeWithoutResult(statut -> {
                String contenuFinal = tronquer(contenu);
                Instant limiteRecente = horloge.instant().minusSeconds(5);
                boolean doublon = notifications.findByUtilisateurIdOrderByDateCreationDesc(utilisateurId, PageRequest.of(0, 5)).stream()
                        .anyMatch(n -> n.getContenu().equals(contenuFinal) && n.getDateCreation().isAfter(limiteRecente));
                if (doublon) {
                    LOG.info("Notification en doublon ignorée pour l'utilisateur {} (même contenu)", utilisateurId);
                    return;
                }
                String telephone = annuaire.telephoneDe(utilisateurId).orElse(null);
                boolean envoye = telephone != null && tenterEnvoi(telephone, contenu);
                notifications.save(new Notification(utilisateurId, contenuFinal,
                        telephone != null ? Notification.Canal.SMS : Notification.Canal.PUSH,
                        (telephone == null || envoye) ? StatutNotification.ENVOYEE : StatutNotification.ECHOUEE,
                        1, horloge.instant()));
            });
        } catch (RuntimeException e) {
            LOG.warn("Notification non enregistrée pour l'utilisateur {}", utilisateurId, e);
        }
    }

    /** RG-70 : les envois en échec sont retentés jusqu'à {@value #MAX_TENTATIVES} fois au total. */
    @Scheduled(fixedDelay = 60_000, initialDelay = 60_000)
    public void retenter() {
        try {
            transactionIndependante.executeWithoutResult(statut -> {
                List<Notification> aRetenter = notifications.findByStatutAndTentativesLessThanOrderByIdAsc(
                        StatutNotification.ECHOUEE, MAX_TENTATIVES, PageRequest.of(0, 50));
                for (Notification n : aRetenter) {
                    String telephone = annuaire.telephoneDe(n.getUtilisateurId()).orElse(null);
                    n.enregistrerTentative(telephone != null && tenterEnvoi(telephone, n.getContenu()));
                }
            });
        } catch (RuntimeException e) {
            LOG.warn("Échec de la relance des notifications", e);
        }
    }

    public record NotificationVue(long id, String contenu, String canal, String statut, Instant date) {
    }

    @Transactional(readOnly = true)
    public List<NotificationVue> mesNotifications(long utilisateurId, int taille) {
        int borne = Math.min(Math.max(taille, 1), 100);
        return notifications.findByUtilisateurIdOrderByDateCreationDesc(utilisateurId, PageRequest.of(0, borne)).stream()
                .map(n -> new NotificationVue(n.getId(), n.getContenu(), n.getCanal().name(), n.getStatut().name(),
                        n.getDateCreation()))
                .toList();
    }

    @Transactional
    public void marquerLue(long utilisateurId, long notificationId) {
        Notification n = notifications.findById(notificationId)
                .filter(x -> x.getUtilisateurId().equals(utilisateurId))
                .orElseThrow(() -> ErreurMetier.nonTrouve("Notification", notificationId));
        n.marquerLue();
    }

    private boolean tenterEnvoi(String telephone, String contenu) {
        try {
            return sms.envoyer(telephone, contenu);
        } catch (RuntimeException e) {
            LOG.warn("Échec d'envoi de SMS pour {}", telephone, e);
            return false;
        }
    }

    private static String tronquer(String contenu) {
        return contenu.length() <= 500 ? contenu : contenu.substring(0, 497) + "...";
    }
}
