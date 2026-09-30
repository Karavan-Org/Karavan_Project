package ml.dogo.logistique.persistence;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EvenementLogistiqueRepository extends JpaRepository<EvenementLogistique, Long> {
    List<EvenementLogistique> findByExpeditionIdOrderByDateAsc(Long expeditionId);
}
