package ml.dogo.finance.persistence;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TauxDeChangeRepository extends JpaRepository<TauxDeChange, Long> {
    Optional<TauxDeChange> findFirstByDeviseSourceAndDeviseCibleOrderByDateDesc(String deviseSource, String deviseCible);
}
