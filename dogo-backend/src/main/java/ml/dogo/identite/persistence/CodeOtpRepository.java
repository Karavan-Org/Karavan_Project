package ml.dogo.identite.persistence;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CodeOtpRepository extends JpaRepository<CodeOtp, Long> {

    Optional<CodeOtp> findFirstByUtilisateurIdAndUtiliseFalseOrderByDateCreationDesc(Long utilisateurId);

    Optional<CodeOtp> findFirstByUtilisateurIdOrderByDateCreationDesc(Long utilisateurId);

    /** Un nouveau code annule les précédents (RG-02). */
    @Modifying
    @Query("update CodeOtp c set c.utilise = true where c.utilisateurId = :uid and c.utilise = false")
    int invaliderAnciens(@Param("uid") Long utilisateurId);

    /**
     * Réserve une tentative de saisie de façon atomique : renvoie 1 si le code est encore utilisable, 0 sinon.
     * Faite avant la comparaison, elle empêche de contourner la limite par des requêtes parallèles (RG-02).
     */
    @Modifying
    @Query("update CodeOtp c set c.tentatives = c.tentatives + 1 "
            + "where c.id = :id and c.utilise = false and c.tentatives < :max and c.expiration > :maintenant")
    int reserverTentative(@Param("id") Long id, @Param("max") int max, @Param("maintenant") Instant maintenant);

    /** Usage unique : renvoie 1 seulement pour le premier appel (RG-02). */
    @Modifying
    @Query("update CodeOtp c set c.utilise = true where c.id = :id and c.utilise = false")
    int consommer(@Param("id") Long id);
}
