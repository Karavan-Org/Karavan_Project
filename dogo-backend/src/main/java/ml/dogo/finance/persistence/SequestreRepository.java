package ml.dogo.finance.persistence;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SequestreRepository extends JpaRepository<Sequestre, Long> {

    Optional<Sequestre> findByPaiementId(Long paiementId);
}
