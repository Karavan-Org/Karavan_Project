package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.finance.api.FinanceApi;
import ml.dogo.finance.domain.RegleFinance;
import ml.dogo.finance.domain.StatutPaiement;
import ml.dogo.finance.domain.TypeMouvement;
import ml.dogo.finance.persistence.FraisPlateforme;
import ml.dogo.finance.persistence.FraisPlateformeRepository;
import ml.dogo.finance.persistence.Paiement;
import ml.dogo.finance.persistence.PaiementRepository;
import ml.dogo.finance.persistence.PorteFeuilleCourtierRepository;
import ml.dogo.finance.persistence.Sequestre;
import ml.dogo.finance.persistence.SequestreRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.persistence.Verrou;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Libération du séquestre au scan valide du code de retrait (RG-36 à RG-40). */
@Service
public class FinanceApiImpl implements FinanceApi {

    private final PaiementRepository paiements;
    private final SequestreRepository sequestres;
    private final PorteFeuilleCourtierRepository portefeuilles;
    private final FraisPlateformeRepository frais;
    private final MouvementService mouvements;
    private final ParticipationApi participations;
    private final GroupeAchatApi campagne;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final Verrou verrou;
    private final Clock horloge;

    public FinanceApiImpl(PaiementRepository paiements, SequestreRepository sequestres,
                          PorteFeuilleCourtierRepository portefeuilles, FraisPlateformeRepository frais,
                          MouvementService mouvements, ParticipationApi participations, GroupeAchatApi campagne,
                          AuditApi audit, NotificationApi notifications, Verrou verrou, Clock horloge) {
        this.paiements = paiements;
        this.sequestres = sequestres;
        this.portefeuilles = portefeuilles;
        this.frais = frais;
        this.mouvements = mouvements;
        this.participations = participations;
        this.campagne = campagne;
        this.audit = audit;
        this.notifications = notifications;
        this.verrou = verrou;
        this.horloge = horloge;
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void libererSequestre(long participationId) {
        long paiementId = paiements.findFirstByParticipationIdAndStatut(participationId, StatutPaiement.PAYE)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.CONFLIT, "RG-38", "Aucun paiement à libérer pour cette commande"))
                .getId();
        Paiement p = verrou.ecriture(Paiement.class, paiementId).orElseThrow();
        long sequestreId = sequestres.findByPaiementId(paiementId)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.CONFLIT, "RG-36", "Aucun séquestre pour ce paiement")).getId();
        Sequestre s = verrou.ecriture(Sequestre.class, sequestreId).orElseThrow();

        ParticipationApi.ParticipationInfo part = participations.participation(participationId).orElseThrow();
        GroupeAchatApi.GroupeInfo g = campagne.groupe(part.groupeId()).orElseThrow();
        BigDecimal montantBloque = s.getMontantBloque();
        // RG-37 : frais figés à la réservation ; RG-38 : le Courtier reçoit le reste.
        BigDecimal fraisMontant = part.fraisUnitaireFige().multiply(BigDecimal.valueOf(part.quantite()));
        BigDecimal versement = RegleFinance.partCourtier(montantBloque, fraisMontant);
        long portefeuilleId = mouvements.portefeuilleDe(g.courtierId()).getId();
        Instant maintenant = horloge.instant();

        s.liberer(maintenant);   // refuse un séquestre gelé (RG-62) ou déjà traité
        frais.save(new FraisPlateforme(paiementId, fraisMontant, g.tauxCommission(), maintenant));
        if (portefeuilles.liberer(portefeuilleId, montantBloque, versement) != 1) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-41", "Solde bloqué du courtier incohérent : libération refusée");
        }
        if (versement.signum() > 0) {
            mouvements.enregistrer(paiementId, portefeuilleId, TypeMouvement.LIBERATION_SEQUESTRE, versement,
                    "PAIEMENT-" + paiementId + "-LIBERATION");
        }
        if (fraisMontant.signum() > 0) {
            mouvements.enregistrer(paiementId, portefeuilleId, TypeMouvement.FRAIS_PLATEFORME, fraisMontant,
                    "PAIEMENT-" + paiementId + "-FRAIS");
        }
        audit.tracer(null, "SEQUESTRE_LIBERE", "paiement=" + paiementId,
                "versement=" + versement + ", frais=" + fraisMontant);
        notifications.notifier(g.courtierId(), versement.toBigInteger() + " XOF sont disponibles dans votre portefeuille.");
    }
}

