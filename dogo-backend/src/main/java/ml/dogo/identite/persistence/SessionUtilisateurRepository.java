package ml.dogo.identite.persistence;

import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SessionUtilisateurRepository extends JpaRepository<SessionUtilisateur, Long> {

    @Modifying
    @Query("update SessionUtilisateur s set s.invalidee = true where s.utilisateurId = :uid and s.invalidee = false")
    int invaliderToutes(@Param("uid") Long utilisateurId);

    /** Purge des sessions terminées depuis longtemps. */
    @Modifying
    @Query("delete from SessionUtilisateur s where s.dateExpiration < :limite or (s.invalidee = true and s.derniereActivite < :limite)")
    int purger(@Param("limite") Instant limite);
}
