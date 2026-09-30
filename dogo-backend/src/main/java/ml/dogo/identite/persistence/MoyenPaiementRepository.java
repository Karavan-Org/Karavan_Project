package ml.dogo.identite.persistence;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MoyenPaiementRepository extends JpaRepository<MoyenPaiementUtilisateur, Long> {

    List<MoyenPaiementUtilisateur> findByUtilisateurIdOrderByIdAsc(Long utilisateurId);

    Optional<MoyenPaiementUtilisateur> findByIdAndUtilisateurId(Long id, Long utilisateurId);

    Optional<MoyenPaiementUtilisateur> findFirstByUtilisateurIdAndParDefautTrue(Long utilisateurId);

    boolean existsByUtilisateurIdAndNumeroMobileMoney(Long utilisateurId, String numero);

    /** RG-10 : on retire l'ancien défaut avant d'en poser un nouveau (unicité portée par la base). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update MoyenPaiementUtilisateur m set m.parDefaut = false where m.utilisateurId = :uid and m.parDefaut = true")
    int retirerDefaut(@Param("uid") Long utilisateurId);
}
