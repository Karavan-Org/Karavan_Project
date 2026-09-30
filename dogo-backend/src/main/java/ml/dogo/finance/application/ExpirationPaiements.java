package ml.dogo.finance.application;

import java.time.Clock;
import ml.dogo.finance.persistence.PaiementRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Abandonne les paiements sans réponse de l'opérateur après le délai autorisé. */
@Component
public class ExpirationPaiements {

    private static final Logger LOG = LoggerFactory.getLogger(ExpirationPaiements.class);

    private final PaiementRepository paiements;
    private final PaiementService service;
    private final Clock horloge;

    public ExpirationPaiements(PaiementRepository paiements, PaiementService service, Clock horloge) {
        this.paiements = paiements;
        this.service = service;
        this.horloge = horloge;
    }

    @Scheduled(fixedDelay = 60_000, initialDelay = 45_000)
    public void expirer() {
        for (Long id : paiements.identifiantsEnCoursAvant(horloge.instant().minus(PaiementService.DELAI_REPONSE_OPERATEUR))) {
            try {
                service.expirer(id);
            } catch (RuntimeException e) {
                LOG.error("Expiration du paiement {} impossible", id, e);
            }
        }
    }
}
