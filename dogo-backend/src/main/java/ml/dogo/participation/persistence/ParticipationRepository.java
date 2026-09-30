package ml.dogo.participation.persistence;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import ml.dogo.participation.domain.StatutParticipation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ParticipationRepository extends JpaRepository<Participation, Long> {

    List<Participation> findByCommercantIdOrderByIdDesc(Long commercantId);

    List<Participation> findByGroupeIdAndStatut(Long groupeId, StatutParticipation statut);

    List<Participation> findByGroupeIdAndStatutIn(Long groupeId, Collection<StatutParticipation> statuts);

    boolean existsByGroupeIdAndCommercantIdAndVarianteIdAndStatutIn(Long groupeId, Long commercantId, Long varianteId,
                                                                    Collection<StatutParticipation> statuts);

    @Query("select p.id from Participation p where p.groupeId = :groupeId and p.statut in :statuts order by p.id")
    List<Long> identifiantsDuGroupe(@Param("groupeId") Long groupeId, @Param("statuts") Collection<StatutParticipation> statuts);

    @Query("select p.id from Participation p where p.statut in (ml.dogo.participation.domain.StatutParticipation.DEMANDEE, "
            + "ml.dogo.participation.domain.StatutParticipation.RESERVEE) and p.dateExpirationReservation <= :maintenant")
    List<Long> identifiantsReservationsEchues(@Param("maintenant") Instant maintenant);
}
