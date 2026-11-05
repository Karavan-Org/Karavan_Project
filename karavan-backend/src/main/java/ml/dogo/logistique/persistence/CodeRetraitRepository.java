package ml.dogo.logistique.persistence;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CodeRetraitRepository extends JpaRepository<CodeRetrait, Long> {

    Optional<CodeRetrait> findByCommandeId(Long commandeId);

    Optional<CodeRetrait> findByTokenHash(String tokenHash);

    Optional<CodeRetrait> findByCodeCourtHash(String codeCourtHash);

    /** Identifiant de la commande d'un jeton QR, sans charger l'entité (l'état du code est lu après le verrou de la commande). */
    @Query(nativeQuery = true, value = "SELECT commande_id FROM code_retrait WHERE qr_token = :jeton")
    Optional<Long> commandeDuJeton(@Param("jeton") String jeton);

    @Query(nativeQuery = true, value = "SELECT commande_id FROM code_retrait WHERE token_hash = :hash OR qr_token = :token")
    Optional<Long> commandeDuJetonOuHash(@Param("token") String token, @Param("hash") String hash);

    @Query(nativeQuery = true, value = "SELECT commande_id FROM code_retrait WHERE code_court_hash = :hash")
    Optional<Long> commandeDuCodeCourtHash(@Param("hash") String hash);

    /**
     * Un échec de saisie : le drapeau « bloqué » est calculé avec l'ancienne valeur du compteur, donc avant son
     * incrément (MySQL évalue les affectations de gauche à droite) ; le code se bloque au maximum d'échecs (RG-54).
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE code_retrait SET bloque = (tentatives + 1 >= :max), "
            + "statut = CASE WHEN (tentatives + 1 >= :max) THEN 'BLOQUE' ELSE statut END, "
            + "tentatives = tentatives + 1 "
            + "WHERE id = :id AND utilise = FALSE AND bloque = FALSE")
    int enregistrerEchec(@Param("id") long id, @Param("max") int max);

    @Query(nativeQuery = true, value = "SELECT tentatives FROM code_retrait WHERE id = :id")
    int tentatives(@Param("id") long id);

    /** Usage unique : renvoie 1 pour le seul appel qui consomme le code (RG-54). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE code_retrait SET utilise = TRUE, statut = 'UTILISE', date_utilisation = :maintenant "
            + "WHERE id = :id AND utilise = FALSE AND bloque = FALSE "
            + "AND expiration > :maintenant")
    int consommer(@Param("id") long id, @Param("maintenant") java.time.Instant maintenant);

    /** Consommation avec traçabilité de l'acteur qui valide. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE code_retrait SET utilise = TRUE, statut = 'UTILISE', "
            + "date_utilisation = :maintenant, valide_par_id = :valideParId "
            + "WHERE id = :id AND statut = 'ACTIF' AND utilise = FALSE AND bloque = FALSE "
            + "AND expiration > :maintenant")
    int consommerAvecActeur(@Param("id") long id, @Param("maintenant") java.time.Instant maintenant, @Param("valideParId") Long valideParId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE code_retrait SET statut = 'ANNULE' WHERE commande_id = :commandeId AND statut = 'ACTIF'")
    int annulerActifsDeCommande(@Param("commandeId") long commandeId);
}
