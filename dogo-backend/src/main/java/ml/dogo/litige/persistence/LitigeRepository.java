package ml.dogo.litige.persistence;

import java.util.List;
import ml.dogo.litige.domain.StatutLitige;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LitigeRepository extends JpaRepository<Litige, Long> {
    List<Litige> findByCommandeId(Long commandeId);
    List<Litige> findByStatut(StatutLitige statut);
}
