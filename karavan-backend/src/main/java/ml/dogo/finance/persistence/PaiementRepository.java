package ml.dogo.finance.persistence;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import ml.dogo.finance.domain.StatutPaiement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaiementRepository extends JpaRepository<Paiement, Long> {

    Optional<Paiement> findByCleIdempotence(String cleIdempotence);

    List<Paiement> findByParticipationIdOrderByIdDesc(Long participationId);

    Optional<Paiement> findFirstByParticipationIdAndStatut(Long participationId, StatutPaiement statut);

    /** Paiement « vivant » : en cours ou réussi (RG-34). */
    @Query("select count(p) > 0 from Paiement p where p.participationId = :participationId and p.statut in "
            + "(ml.dogo.finance.domain.StatutPaiement.INITIE, ml.dogo.finance.domain.StatutPaiement.EN_ATTENTE, "
            + "ml.dogo.finance.domain.StatutPaiement.PAYE)")
    boolean existeVivant(@Param("participationId") Long participationId);

    /** Paiement en cours (sans callback reçu) : bloque l'expiration de la réservation. */
    @Query("select count(p) > 0 from Paiement p where p.participationId = :participationId and p.statut in "
            + "(ml.dogo.finance.domain.StatutPaiement.INITIE, ml.dogo.finance.domain.StatutPaiement.EN_ATTENTE)")
    boolean existeEnCours(@Param("participationId") Long participationId);

    @Query("select p.id from Paiement p where p.statut in (ml.dogo.finance.domain.StatutPaiement.INITIE, "
            + "ml.dogo.finance.domain.StatutPaiement.EN_ATTENTE) and p.dateInitiation <= :limite")
    List<Long> identifiantsEnCoursAvant(@Param("limite") Instant limite);

    @Query("select p.id from Paiement p where p.participationId in :participationIds")
    List<Long> paiementIdsPourParticipations(@Param("participationIds") java.util.Collection<Long> participationIds);
}
