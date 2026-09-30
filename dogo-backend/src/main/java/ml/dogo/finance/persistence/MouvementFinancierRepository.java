package ml.dogo.finance.persistence;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MouvementFinancierRepository extends JpaRepository<MouvementFinancier, Long> {

    List<MouvementFinancier> findByPortefeuilleIdOrderByIdDesc(Long portefeuilleId, Pageable page);

    boolean existsByReference(String reference);
}
