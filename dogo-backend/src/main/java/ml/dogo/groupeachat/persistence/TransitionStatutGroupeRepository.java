package ml.dogo.groupeachat.persistence;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TransitionStatutGroupeRepository extends JpaRepository<TransitionStatutGroupe, Long> {

    List<TransitionStatutGroupe> findByGroupeIdOrderByIdAsc(Long groupeId);
}

