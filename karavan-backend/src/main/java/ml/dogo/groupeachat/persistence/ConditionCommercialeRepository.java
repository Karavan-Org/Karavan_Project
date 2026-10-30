package ml.dogo.groupeachat.persistence;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConditionCommercialeRepository extends JpaRepository<ConditionCommerciale, Long> {

    Optional<ConditionCommerciale> findByGroupeId(Long groupeId);
}

