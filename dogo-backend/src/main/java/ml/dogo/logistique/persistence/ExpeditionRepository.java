package ml.dogo.logistique.persistence;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ExpeditionRepository extends JpaRepository<Expedition, Long> {
    Optional<Expedition> findByReference(String reference);
    Optional<Expedition> findByGroupeId(Long groupeId);
    List<Expedition> findByGroupeIdIn(Collection<Long> groupeIds);
}
