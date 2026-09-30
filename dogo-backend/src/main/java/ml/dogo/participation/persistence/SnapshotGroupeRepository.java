package ml.dogo.participation.persistence;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SnapshotGroupeRepository extends JpaRepository<SnapshotGroupe, Long> {

    Optional<SnapshotGroupe> findByParticipationId(Long participationId);
}
