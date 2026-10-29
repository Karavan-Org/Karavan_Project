package ml.dogo.groupeachat.persistence;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GrilleTarifaireRepository extends JpaRepository<GrilleTarifaire, Long> {

    Optional<GrilleTarifaire> findByGroupeId(Long groupeId);
}

