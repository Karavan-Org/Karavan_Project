package ml.dogo.participation.persistence;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HistoriqueParticipationRepository extends JpaRepository<HistoriqueParticipation, Long> {

    List<HistoriqueParticipation> findByParticipationIdOrderByIdAsc(Long participationId);
}
