package ml.dogo.identite.persistence;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import ml.dogo.identite.domain.StatutValidation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DossierKycRepository extends JpaRepository<DossierKyc, Long> {

    boolean existsByUtilisateurIdAndStatut(Long utilisateurId, StatutValidation statut);

    List<DossierKyc> findByStatutOrderByDateSoumissionAsc(StatutValidation statut);

    Optional<DossierKyc> findFirstByUtilisateurIdOrderByDateSoumissionDesc(Long utilisateurId);

    List<DossierKyc> findByUtilisateurIdOrderByDateSoumissionDesc(Long utilisateurId);

    /** Verrou d'écriture : deux administrateurs ne peuvent pas décider le même dossier en même temps (RG-05). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select d from DossierKyc d where d.id = :id")
    Optional<DossierKyc> trouverPourDecision(@Param("id") Long id);
}
