package ml.dogo.participation.application;

import java.util.List;
import java.util.Optional;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.participation.domain.StatutParticipation;
import ml.dogo.participation.persistence.Participation;
import ml.dogo.participation.persistence.ParticipationRepository;
import ml.dogo.participation.persistence.SnapshotGroupe;
import ml.dogo.participation.persistence.SnapshotGroupeRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ParticipationApiImpl implements ParticipationApi {

    private final ParticipationRepository participations;
    private final SnapshotGroupeRepository snapshots;
    private final ParticipationService service;

    public ParticipationApiImpl(ParticipationRepository participations, SnapshotGroupeRepository snapshots,
                                ParticipationService service) {
        this.participations = participations;
        this.snapshots = snapshots;
        this.service = service;
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<ParticipationInfo> participation(long participationId) {
        return participations.findById(participationId).map(this::info);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ParticipationInfo> confirmees(long groupeId) {
        return participations.findByGroupeIdAndStatut(groupeId, StatutParticipation.CONFIRMEE).stream()
                .map(this::info).toList();
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean confirmerApresPaiement(long participationId) {
        return service.confirmerApresPaiement(participationId);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Long> groupeIdsParCommercant(long commercantId) {
        return participations.findByCommercantIdOrderByIdDesc(commercantId).stream()
                .map(Participation::getGroupeId).distinct().toList();
    }

    private ParticipationInfo info(Participation p) {
        SnapshotGroupe s = snapshots.findByParticipationId(p.getId()).orElseThrow();
        return new ParticipationInfo(p.getId(), p.getGroupeId(), p.getCommercantId(), p.getVarianteId(),
                p.getQuantite(), p.getStatut().name(), s.getPrixFige(), s.getFraisUnitaireFige(),
                p.getDateExpirationReservation());
    }
}
