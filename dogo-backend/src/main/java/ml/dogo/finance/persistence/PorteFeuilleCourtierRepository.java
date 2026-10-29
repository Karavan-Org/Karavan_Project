package ml.dogo.finance.persistence;

import java.math.BigDecimal;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PorteFeuilleCourtierRepository extends JpaRepository<PorteFeuilleCourtier, Long> {

    Optional<PorteFeuilleCourtier> findByCourtierId(Long courtierId);

    /** Création paresseuse, sûre sous concurrence grâce à l'unicité du courtier. */
    @Modifying
    @Query(nativeQuery = true, value = "INSERT INTO portefeuille (courtier_id) VALUES (:courtier) "
            + "ON DUPLICATE KEY UPDATE courtier_id = courtier_id")
    int creerSiAbsent(@Param("courtier") long courtierId);

    /** Un paiement reçu ajoute au solde bloqué du Courtier (RG-36, RG-41). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE portefeuille SET solde_bloque = solde_bloque + :montant WHERE id = :id")
    int bloquer(@Param("id") long id, @Param("montant") BigDecimal montant);

    /** Restitution au Commerçant : le solde bloqué diminue, sans jamais devenir négatif. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE portefeuille SET solde_bloque = solde_bloque - :montant "
            + "WHERE id = :id AND solde_bloque >= :montant")
    int debloquer(@Param("id") long id, @Param("montant") BigDecimal montant);

    /** Libération (RG-38) : le bloqué devient disponible, moins les frais de plateforme. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE portefeuille SET solde_bloque = solde_bloque - :bloque, "
            + "solde_disponible = solde_disponible + :verse WHERE id = :id AND solde_bloque >= :bloque")
    int liberer(@Param("id") long id, @Param("bloque") BigDecimal bloque, @Param("verse") BigDecimal verse);

    /** Retrait (RG-41) : seul le solde disponible peut sortir. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE portefeuille SET solde_disponible = solde_disponible - :montant "
            + "WHERE id = :id AND solde_disponible >= :montant")
    int retirer(@Param("id") long id, @Param("montant") BigDecimal montant);

    /** Crédit direct du solde disponible (recharge, remboursement restitué et conservé dans le portefeuille). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE portefeuille SET solde_disponible = solde_disponible + :montant WHERE id = :id")
    int crediterDisponible(@Param("id") long id, @Param("montant") BigDecimal montant);

    /** Débit du solde disponible lors d'un achat ou d'une dépense par portefeuille. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE portefeuille SET solde_disponible = solde_disponible - :montant "
            + "WHERE id = :id AND solde_disponible >= :montant")
    int debiterDisponible(@Param("id") long id, @Param("montant") BigDecimal montant);
}
