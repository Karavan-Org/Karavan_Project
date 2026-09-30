package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.time.Clock;
import ml.dogo.finance.domain.TypeMouvement;
import ml.dogo.finance.persistence.MouvementFinancier;
import ml.dogo.finance.persistence.MouvementFinancierRepository;
import ml.dogo.finance.persistence.PorteFeuilleCourtier;
import ml.dogo.finance.persistence.PorteFeuilleCourtierRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Écriture du journal financier immuable (RG-40) et accès aux portefeuilles courtiers. */
@Service
public class MouvementService {

    private final MouvementFinancierRepository mouvements;
    private final PorteFeuilleCourtierRepository portefeuilles;
    private final Clock horloge;

    public MouvementService(MouvementFinancierRepository mouvements, PorteFeuilleCourtierRepository portefeuilles, Clock horloge) {
        this.mouvements = mouvements;
        this.portefeuilles = portefeuilles;
        this.horloge = horloge;
    }

    /** RG-40 : la référence est unique, donc rejouer une opération ne peut pas créer un second mouvement. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void enregistrer(Long paiementId, Long portefeuilleId, TypeMouvement type, BigDecimal montant, String reference) {
        mouvements.save(new MouvementFinancier(paiementId, portefeuilleId, type, montant, horloge.instant(), reference));
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public PorteFeuilleCourtier portefeuilleDe(long courtierId) {
        portefeuilles.creerSiAbsent(courtierId);
        return portefeuilles.findByCourtierId(courtierId).orElseThrow();
    }
}
