package ml.dogo.logistique.persistence;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QrColisRepository extends JpaRepository<QrColis, Long> {

    Optional<QrColis> findByExpeditionIdAndStatut(Long expeditionId, String statut);

    Optional<QrColis> findFirstByExpeditionIdOrderByDateCreationDesc(Long expeditionId);

    List<QrColis> findByExpeditionIdOrderByDateCreationDesc(Long expeditionId);

    Optional<QrColis> findByTokenHash(String tokenHash);

    Optional<QrColis> findByCodeCourtHash(String codeCourtHash);

    /** Usage unique atomique : renvoie 1 si le QR a été consommé, 0 sinon. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE qr_colis SET statut = 'UTILISE', date_utilisation = :maintenant, valide_par_id = :valideParId "
            + "WHERE id = :id AND statut = 'ACTIF' AND expiration > :maintenant")
    int consommer(@Param("id") long id, @Param("maintenant") Instant maintenant, @Param("valideParId") Long valideParId);

    /** Annulation atomique de tous les codes actifs d'une expédition lors d'une régénération. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE qr_colis SET statut = 'ANNULE' WHERE expedition_id = :expeditionId AND statut = 'ACTIF'")
    int annulerActifsDeExpedition(@Param("expeditionId") long expeditionId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE qr_colis SET tentatives = tentatives + 1 WHERE id = :id")
    int enregistrerEchec(@Param("id") long id);
}

