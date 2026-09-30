package ml.dogo.notification.persistence;

import java.util.List;
import ml.dogo.notification.domain.StatutNotification;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    List<Notification> findByUtilisateurIdOrderByDateCreationDesc(Long utilisateurId, Pageable pageable);

    List<Notification> findByStatutAndTentativesLessThanOrderByIdAsc(StatutNotification statut, int tentatives,
                                                                    Pageable pageable);
}
