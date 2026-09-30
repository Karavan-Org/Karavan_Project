package ml.dogo.finance.persistence;

import java.util.List;
import ml.dogo.finance.domain.StatutRemboursement;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RemboursementRepository extends JpaRepository<Remboursement, Long> {

    List<Remboursement> findByStatutOrderByIdAsc(StatutRemboursement statut);

    List<Remboursement> findByPaiementIdOrderByIdAsc(Long paiementId);

    boolean existsByPaiementIdAndStatutIn(Long paiementId, java.util.Collection<StatutRemboursement> statuts);
}
