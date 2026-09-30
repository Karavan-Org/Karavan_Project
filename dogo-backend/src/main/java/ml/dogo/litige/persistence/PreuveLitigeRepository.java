package ml.dogo.litige.persistence;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PreuveLitigeRepository extends JpaRepository<PreuveLitige, Long> {
    List<PreuveLitige> findByLitigeId(Long litigeId);
}
