package ml.dogo.logistique.persistence;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CodeRetraitRepository extends JpaRepository<CodeRetrait, Long> {

    Optional<CodeRetrait> findByCommandeId(Long commandeId);

    /** Identifiant de la commande d'un jeton QR, sans charger l'entité (l'état du code est lu après le verrou de la commande). */
    @Query(nativeQuery = true, value = "SELECT commande_id FROM code_retrait WHERE qr_token = :jeton")
    Optional<Long> commandeDuJeton(@Param("jeton") String jeton);

    /**
     * Un échec de saisie : le drapeau « bloqué » est calculé avec l'ancienne valeur du compteur, donc avant son
     * incrément (MySQL évalue les affectations de gauche à droite) ; le code se bloque au maximum d'échecs (RG-54).
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE code_retrait SET bloque = (tentatives + 1 >= :max), tentatives = tentatives + 1 "
            + "WHERE id = :id AND utilise = FALSE AND bloque = FALSE")
    int enregistrerEchec(@Param("id") long id, @Param("max") int max);

    @Query(nativeQuery = true, value = "SELECT tentatives FROM code_retrait WHERE id = :id")
    int tentatives(@Param("id") long id);

    /** Usage unique : renvoie 1 pour le seul appel qui consomme le code (RG-54). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE code_retrait SET utilise = TRUE WHERE id = :id AND utilise = FALSE AND bloque = FALSE "
            + "AND expiration > :maintenant")
    int consommer(@Param("id") long id, @Param("maintenant") java.time.Instant maintenant);
}
