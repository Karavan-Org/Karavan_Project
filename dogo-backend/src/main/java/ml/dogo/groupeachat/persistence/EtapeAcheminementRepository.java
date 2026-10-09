package ml.dogo.groupeachat.persistence;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EtapeAcheminementRepository extends JpaRepository<EtapeAcheminement, Long> {

    List<EtapeAcheminement> findByGroupeIdOrderByIdAsc(Long groupeId);
}
