package ml.dogo.finance.application;

import java.math.BigDecimal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/** Simulation : aucune vraie transaction. En démo, /api/dev/mobile-money/{id}/succes joue le rôle de l'opérateur. */
@Component
public class PasserelleMobileMoneySimulee implements PasserelleMobileMoney {

    private static final Logger LOG = LoggerFactory.getLogger("dogo.mobilemoney");

    @Override
    public void demanderDebit(String reference, String numero, String operateur, BigDecimal montant) {
        LOG.info("[Mobile Money simulé] demande de débit {} de {} XOF sur {} ({})", reference, montant, numero, operateur);
    }

    @Override
    public void rembourser(String reference, String numero, String operateur, BigDecimal montant) {
        LOG.info("[Mobile Money simulé] remboursement {} de {} XOF vers {} ({})", reference, montant, numero, operateur);
    }

    @Override
    public void verser(String reference, String numero, String operateur, BigDecimal montant) {
        LOG.info("[Mobile Money simulé] versement {} de {} XOF vers {} ({})", reference, montant, numero, operateur);
    }
}
