package ml.dogo.logistique.persistence;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ExpeditionRepository extends JpaRepository<Expedition, Long> {
    Optional<Expedition> findByReference(String reference);
    Optional<Expedition> findByGroupeId(Long groupeId);
}
