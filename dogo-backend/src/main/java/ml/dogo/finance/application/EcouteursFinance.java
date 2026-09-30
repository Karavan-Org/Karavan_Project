package ml.dogo.finance.application;

import ml.dogo.finance.domain.MotifRemboursement;
import ml.dogo.finance.domain.StatutPaiement;
import ml.dogo.finance.persistence.PaiementRepository;
import ml.dogo.participation.api.Evenements;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/** Réactions du module finance aux événements de la participation (dans la transaction qui les publie). */
@Component
public class EcouteursFinance {

    private static final Logger LOG = LoggerFactory.getLogger(EcouteursFinance.class);

    private final PaiementRepository paiements;
    private final RemboursementService remboursements;

    public EcouteursFinance(PaiementRepository paiements, RemboursementService remboursements) {
        this.paiements = paiements;
        this.remboursements = remboursements;
    }

    /**
     * Une participation payée est annulée (par le client avant l'objectif, ou parce que le groupe échoue / est annulé) :
     * remboursement automatique, RG-31, RG-22, RG-24, RG-60. Une participation non payée n'a rien à rembourser ; son éventuel
     * paiement en cours se règle par le callback ou par l'expiration.
     */
    @EventListener
    public void participationAnnulee(Evenements.ParticipationAnnulee e) {
        if (!e.payee()) {
            return;
        }
        paiements.findFirstByParticipationIdAndStatut(e.participationId(), StatutPaiement.PAYE).ifPresentOrElse(
                p -> remboursements.demander(p.getId(), MotifRemboursement.valueOf(e.motif()), null),
                () -> LOG.error("Participation {} payée mais sans paiement PAYE : remboursement impossible",
                        e.participationId()));
    }

    /** Une réservation ne doit pas expirer tant qu'un paiement est en cours (RG-28). */
    @EventListener
    public void verifierExpiration(Evenements.VerificationExpiration question) {
        if (paiements.existeEnCours(question.participationId())) {
            question.opposerVeto();
        }
    }
}
