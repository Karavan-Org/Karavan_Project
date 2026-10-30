package ml.dogo.groupeachat.persistence;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PaysRepository extends JpaRepository<Pays, String> {

    List<Pays> findByActifTrueOrderByNomFrAsc();

    Optional<Pays> findByCodeIsoIgnoreCase(String codeIso);

    Optional<Pays> findByCodeIso3IgnoreCase(String codeIso3);
}

