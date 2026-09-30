package ml.dogo.logistique.persistence;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PointRetraitRepository extends JpaRepository<PointRetrait, Long> {

    List<PointRetrait> findAllByOrderByNomAsc();
}
