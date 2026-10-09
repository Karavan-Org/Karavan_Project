package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.finance.domain.MotifRemboursement;
import ml.dogo.finance.domain.RegleFinance;
import ml.dogo.finance.domain.StatutPaiement;
import ml.dogo.finance.domain.StatutRemboursement;
import ml.dogo.finance.domain.StatutSequestre;
import ml.dogo.finance.domain.TypeMouvement;
import ml.dogo.finance.persistence.Paiement;
import ml.dogo.finance.persistence.PorteFeuilleCourtierRepository;
import ml.dogo.finance.persistence.Remboursement;
import ml.dogo.finance.persistence.RemboursementRepository;
import ml.dogo.finance.persistence.Sequestre;
import ml.dogo.finance.persistence.SequestreRepository;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.persistence.Verrou;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Remboursements (RG-57 à RG-60). Toutes les méthodes suivent le même ordre : verrouiller les lignes, modifier les
 * entités, puis lancer les requêtes SQL atomiques sur le portefeuille (qui enregistrent les modifications et vident
 * le contexte de persistance) ; après elles, on n'utilise plus que des valeurs déjà lues.
 */
@Service
public class RemboursementService {

    public record RemboursementVue(long id, long paiementId, BigDecimal montant, String statut, String motif,
                                   Instant dateDemande) {
    }

    private final RemboursementRepository remboursements;
    private final SequestreRepository sequestres;
    private final PorteFeuilleCourtierRepository portefeuilles;
    private final MouvementService mouvements;
    private final ParticipationApi participations;
    private final GroupeAchatApi campagne;
    private final IdentiteApi identite;
    private final PasserelleMobileMoney passerelle;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final Verrou verrou;
    private final Clock horloge;

    public RemboursementService(RemboursementRepository remboursements, SequestreRepository sequestres,
                                PorteFeuilleCourtierRepository portefeuilles, MouvementService mouvements,
                                ParticipationApi participations, GroupeAchatApi campagne, IdentiteApi identite,
                                PasserelleMobileMoney passerelle, AuditApi audit, NotificationApi notifications,
                                Verrou verrou, Clock horloge) {
        this.remboursements = remboursements;
        this.sequestres = sequestres;
        this.portefeuilles = portefeuilles;
        this.mouvements = mouvements;
        this.participations = participations;
        this.campagne = campagne;
        this.identite = identite;
        this.passerelle = passerelle;
        this.audit = audit;
        this.notifications = notifications;
        this.verrou = verrou;
        this.horloge = horloge;
    }

    /**
     * RG-57 : crée une demande pour un paiement PAYE. RG-60 : échec du groupe, échec du fournisseur ou annulation par le
     * client sont approuvés et exécutés aussitôt ; les autres motifs attendent un administrateur FINANCE.
     */
    @Transactional
    public RemboursementVue demander(long paiementId, MotifRemboursement motif, Long demandeurId) {
        Paiement p = verrou.ecriture(Paiement.class, paiementId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Paiement", paiementId));
        if (p.getStatut() != StatutPaiement.PAYE) {
            throw new ErreurMetier(CodeErreur.REMBOURSEMENT_INVALIDE, "RG-57", "Seul un paiement PAYE est remboursable");
        }
        Sequestre s = sequestreVerrouille(paiementId);
        verifierSequestreRemboursable(s, motif);
        if (remboursements.existsByPaiementIdAndStatutIn(paiementId,
                EnumSet.of(StatutRemboursement.DEMANDE, StatutRemboursement.APPROUVE))) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-57", "Une demande de remboursement est déjà en cours");
        }
        // Tant que le séquestre est bloqué, on restitue la totalité (RG-59) ; RG-58 borne le montant au payé.
        BigDecimal montant = p.restantRemboursable();
        RegleFinance.verifierMontantRemboursable(p.getMontant(), p.getMontantRembourse(), montant);
        Instant maintenant = horloge.instant();
        Remboursement r = remboursements.save(new Remboursement(paiementId, montant, motif, maintenant));
        audit.tracer(demandeurId, "REMBOURSEMENT_DEMANDE", "paiement=" + paiementId,
                "motif=" + motif + ", montant=" + montant);
        if (motif.automatique()) {
            r.approuver(null, maintenant);
            executer(r, p, s);
        }
        return vue(r);
    }

    /** RG-60 : un administrateur FINANCE approuve, et le remboursement est exécuté. */
    @Transactional
    public RemboursementVue approuver(long adminId, long remboursementId) {
        exigerFinance(adminId);
        Remboursement r = verrou.ecriture(Remboursement.class, remboursementId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Remboursement", remboursementId));
        Paiement p = verrou.ecriture(Paiement.class, r.getPaiementId()).orElseThrow();
        Sequestre s = sequestreVerrouille(p.getId());
        verifierSequestreRemboursable(s, r.getMotif());
        RegleFinance.verifierMontantRemboursable(p.getMontant(), p.getMontantRembourse(), r.getMontant());
        r.approuver(adminId, horloge.instant());
        audit.tracer(adminId, "REMBOURSEMENT_APPROUVE", "remboursement=" + remboursementId, null);
        executer(r, p, s);
        return vue(r);
    }

    @Transactional
    public RemboursementVue rejeter(long adminId, long remboursementId, String justification) {
        exigerFinance(adminId);
        if (justification == null || justification.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-68", "Un rejet doit être justifié");
        }
        Remboursement r = verrou.ecriture(Remboursement.class, remboursementId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Remboursement", remboursementId));
        r.rejeter(adminId, horloge.instant());
        audit.tracer(adminId, "REMBOURSEMENT_REJETE", "remboursement=" + remboursementId, justification);
        return vue(r);
    }

    /** Demande manuelle d'un administrateur FINANCE (colis perdu...), avec justification (RG-68). */
    @Transactional
    public RemboursementVue demanderManuellement(long adminId, long paiementId, MotifRemboursement motif) {
        exigerFinance(adminId);
        if (motif.automatique()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-60",
                    "Ce motif est traité automatiquement, il ne se demande pas manuellement");
        }
        return demander(paiementId, motif, adminId);
    }

    @Transactional(readOnly = true)
    public List<RemboursementVue> enAttente() {
        return remboursements.findByStatutOrderByIdAsc(StatutRemboursement.DEMANDE).stream().map(RemboursementService::vue)
                .toList();
    }

    // ---------------------------------------------------------------------------------- exécution

    private void executer(Remboursement r, Paiement p, Sequestre s) {
        Instant maintenant = horloge.instant();
        BigDecimal montant = r.getMontant();
        long remboursementId = r.getId();
        long paiementId = p.getId();
        ParticipationApi.ParticipationInfo part = participations.participation(p.getParticipationId()).orElseThrow();
        GroupeAchatApi.GroupeInfo g = campagne.groupe(part.groupeId()).orElseThrow();
        long portefeuilleId = mouvements.portefeuilleDe(g.porteurId()).getId();
        IdentiteApi.MoyenPaiementInfo moyen = identite.moyenPaiementDe(part.commercantId(), p.getMoyenPaiementId());

        // 1) modifications des entités
        s.restituer(maintenant);
        p.enregistrerRemboursement(montant, maintenant);
        r.marquerExecute(maintenant);
        // 2) requête atomique sur le portefeuille (enregistre ce qui précède, puis vide le contexte)
        if (portefeuilles.debloquer(portefeuilleId, montant) != 1) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-41", "Solde bloqué du courtier insuffisant pour ce remboursement");
        }
        // 3) effets externes et trace
        String reference = "REMB-" + remboursementId;
        mouvements.enregistrer(paiementId, portefeuilleId, TypeMouvement.REMBOURSEMENT, montant, reference);
        audit.tracer(null, "REMBOURSEMENT_EXECUTE", "paiement=" + paiementId, "montant=" + montant);
        passerelle.rembourser(reference, moyen.numero(), moyen.operateur(), montant);
        notifications.notifier(part.commercantId(),
                "Vous avez été remboursé de " + montant.toBigInteger() + " XOF sur votre compte Mobile Money.");
    }

    // ------------------------------------------------------------------------------- vérifications

    private Sequestre sequestreVerrouille(long paiementId) {
        long id = sequestres.findByPaiementId(paiementId)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.REMBOURSEMENT_INVALIDE, "RG-36",
                        "Aucun séquestre pour ce paiement")).getId();
        return verrou.ecriture(Sequestre.class, id).orElseThrow();
    }

    /** RG-59 : remboursement possible tant que le séquestre est bloqué ; après libération, seule une décision de litige. */
    private static void verifierSequestreRemboursable(Sequestre s, MotifRemboursement motif) {
        if (s.getStatut() != StatutSequestre.BLOQUE) {
            throw new ErreurMetier(CodeErreur.REMBOURSEMENT_INVALIDE, "RG-59",
                    "Les fonds ne sont plus en séquestre : seul un litige résolu peut les rembourser");
        }
        if (s.isGele() && motif != MotifRemboursement.LITIGE_RESOLU) {
            throw new ErreurMetier(CodeErreur.REMBOURSEMENT_INVALIDE, "RG-62",
                    "Séquestre gelé par un litige : seule la décision du litige peut le rembourser");
        }
    }

    private void exigerFinance(long adminId) {
        if (!"FINANCE".equals(identite.roleAdministratif(adminId).orElse(null))) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-60",
                    "Seul un administrateur du rôle FINANCE traite les remboursements");
        }
    }

    private static RemboursementVue vue(Remboursement r) {
        return new RemboursementVue(r.getId(), r.getPaiementId(), r.getMontant(), r.getStatut().name(),
                r.getMotif().name(), r.getDateDemande());
    }
}

