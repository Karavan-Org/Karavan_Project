package ml.dogo.participation.application;

import java.time.Clock;
import ml.dogo.participation.persistence.ParticipationRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** RG-28 : libère les réservations non payées dans le délai, une transaction par participation. */
@Component
public class ExpirationReservations {

    private static final Logger LOG = LoggerFactory.getLogger(ExpirationReservations.class);

    private final ParticipationRepository participations;
    private final ParticipationService service;
    private final Clock horloge;

    public ExpirationReservations(ParticipationRepository participations, ParticipationService service, Clock horloge) {
        this.participations = participations;
        this.service = service;
        this.horloge = horloge;
    }

    @Scheduled(fixedDelay = 30_000, initialDelay = 30_000)
    public void expirer() {
        for (Long id : participations.identifiantsReservationsEchues(horloge.instant())) {
            try {
                service.expirer(id);
            } catch (RuntimeException e) {
                LOG.error("Expiration de la participation {} impossible", id, e);
            }
        }
    }
}
