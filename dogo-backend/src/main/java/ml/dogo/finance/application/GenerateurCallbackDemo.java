package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.util.UUID;
import ml.dogo.finance.persistence.Paiement;
import ml.dogo.finance.persistence.PaiementRepository;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Démonstration uniquement : fabrique le corps JSON qu'enverrait l'opérateur Mobile Money pour un paiement donné. */
@Profile("demo")
@Service
public class GenerateurCallbackDemo {

    private final PaiementRepository paiements;
    private final ParticipationApi participations;
    private final IdentiteApi identite;

    public GenerateurCallbackDemo(PaiementRepository paiements, ParticipationApi participations, IdentiteApi identite) {
        this.paiements = paiements;
        this.participations = participations;
        this.identite = identite;
    }

    @Transactional(readOnly = true)
    public String construire(long paiementId, String statut) {
        Paiement p = paiements.findById(paiementId).orElseThrow(() -> ErreurMetier.nonTrouve("Paiement", paiementId));
        ParticipationApi.ParticipationInfo part = participations.participation(p.getParticipationId()).orElseThrow();
        String operateur = identite.moyenPaiementDe(part.commercantId(), p.getMoyenPaiementId()).operateur();
        BigDecimal montant = p.getMontant();
        return "{\"reference\":\"DOGO-" + paiementId + "\",\"txId\":\"SIM-" + UUID.randomUUID()
                + "\",\"statut\":\"" + statut + "\",\"montant\":" + montant.toPlainString()
                + ",\"operateur\":\"" + operateur + "\"}";
    }
}
