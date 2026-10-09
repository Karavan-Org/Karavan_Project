package ml.dogo.groupeachat.persistence;

import java.time.Instant;
import java.util.List;
import ml.dogo.groupeachat.domain.StatutGroupe;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GroupeAchatRepository extends JpaRepository<GroupeAchat, Long> {

    List<GroupeAchat> findByStatutOrderByDateLimiteAsc(StatutGroupe statut);

    List<GroupeAchat> findByCourtierIdOrderByIdDesc(Long courtierId);

    List<GroupeAchat> findByGrossisteIdAndStatutOrderByIdAsc(Long grossisteId, StatutGroupe statut);

    List<GroupeAchat> findByGrossisteIdOrderByIdDesc(Long grossisteId);

    boolean existsByProduitIdAndStatut(Long produitId, StatutGroupe statut);

    /** Lecture directe en base du statut (les colonnes de statut ne sont jamais écrites par l'entité). */
    @Query("select g.statut from GroupeAchat g where g.id = :id")
    java.util.Optional<StatutGroupe> statutDe(@Param("id") Long id);

    @Query("select g.id from GroupeAchat g where g.statut = ml.dogo.groupeachat.domain.StatutGroupe.OUVERT and g.dateLimite <= :maintenant")
    List<Long> identifiantsOuvertsEchus(@Param("maintenant") Instant maintenant);

    @Query("select count(g) from GroupeAchat g where g.id = :id and g.quantiteConfirmee >= g.quantiteCible")
    long objectifAtteint(@Param("id") Long id);

    // ---- mises à jour atomiques : une seule requête conditionnelle, aucune lecture-puis-écriture (RG-23)

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE groupe_achat SET quantite_reservee = quantite_reservee + :q "
            + "WHERE id = :id AND statut = 'OUVERT' AND date_limite > :maintenant "
            + "AND quantite_confirmee + quantite_reservee + :q <= quantite_cible")
    int reserver(@Param("id") long id, @Param("q") int quantite, @Param("maintenant") Instant maintenant);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE groupe_achat SET quantite_reservee = quantite_reservee - :q "
            + "WHERE id = :id AND quantite_reservee >= :q")
    int libererReservation(@Param("id") long id, @Param("q") int quantite);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE groupe_achat SET quantite_reservee = quantite_reservee - :q, "
            + "quantite_confirmee = quantite_confirmee + :q "
            + "WHERE id = :id AND statut = 'OUVERT' AND quantite_reservee >= :q")
    int confirmer(@Param("id") long id, @Param("q") int quantite);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE groupe_achat SET quantite_confirmee = quantite_confirmee - :q "
            + "WHERE id = :id AND statut = 'OUVERT' AND quantite_confirmee >= :q")
    int retirerConfirmation(@Param("id") long id, @Param("q") int quantite);

    /** Transition d'état conditionnelle : ne réussit que si le statut est encore celui que l'appelant a lu (RG-19). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(nativeQuery = true, value = "UPDATE groupe_achat SET statut = :cible, version = version + 1 "
            + "WHERE id = :id AND statut = :ancien")
    int changerStatut(@Param("id") long id, @Param("ancien") String ancien, @Param("cible") String cible);
}

