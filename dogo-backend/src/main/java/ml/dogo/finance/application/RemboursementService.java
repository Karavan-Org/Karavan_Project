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
import ml.dogo.finance.persistence.PaiementRepository;
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

    public record RemboursementVue(long id, long paiementId, Long participationId, Long groupeId, String produitNom,
                                   BigDecimal montant, String statut, String motif, Instant dateDemande) {
    }

    private final RemboursementRepository remboursements;
    private final PaiementRepository paiements;
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

    public RemboursementService(RemboursementRepository remboursements, PaiementRepository paiements,
                                SequestreRepository sequestres,
                                PorteFeuilleCourtierRepository portefeuilles, MouvementService mouvements,
                                ParticipationApi participations, GroupeAchatApi campagne, IdentiteApi identite,
                                PasserelleMobileMoney passerelle, AuditApi audit, NotificationApi notifications,
                                Verrou verrou, Clock horloge) {
        this.remboursements = remboursements;
        this.paiements = paiements;
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

        // Notifications RG-31 & RG-60 : alerte admin et accusé de traitement pour le commerçant
        ParticipationApi.ParticipationInfo part = participations.participation(p.getParticipationId()).orElse(null);
        if (motif == MotifRemboursement.ANNULATION_CLIENT) {
            String commercantNom = "Commerçant";
            String produitNom = "";
            Long groupeId = null;
            if (part != null) {
                commercantNom = identite.acteur(part.commercantId()).map(IdentiteApi.ActeurInfo::nom)
                        .orElse("Commerçant #" + part.commercantId());
                groupeId = part.groupeId();
                produitNom = campagne.groupe(part.groupeId()).map(GroupeAchatApi.GroupeInfo::produitNom).orElse("");
            }

            // 1. Notifier tous les administrateurs actifs pour action dans l'arbitrage financier
            for (Long adminId : identite.administrateursActifs()) {
                notifications.notifier(adminId, "Demande de remboursement : " + montant.toBigInteger()
                        + " XOF pour le commerçant " + commercantNom
                        + (produitNom.isEmpty() ? "" : " (Groupe #" + (groupeId != null ? groupeId : "") + " - " + produitNom + ")")
                        + ". En attente de votre traitement.");
            }

            // 2. Notifier immédiatement le commerçant que sa demande est prise en compte et en cours de traitement
            if (part != null) {
                notifications.notifier(part.commercantId(),
                        "Votre demande de remboursement de " + montant.toBigInteger()
                        + " FCFA pour « " + (produitNom.isEmpty() ? "votre commande" : produitNom)
                        + " » a bien été enregistrée. Elle est actuellement en cours de traitement par l'administration DoGo. Les fonds vous seront restitués après validation.");
            }
        }

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
        Paiement p = verrou.ecriture(Paiement.class, r.getPaiementId()).orElseThrow();
        ParticipationApi.ParticipationInfo part = participations.participation(p.getParticipationId()).orElse(null);
        if (part != null) {
            String nomProduit = campagne.groupe(part.groupeId()).map(GroupeAchatApi.GroupeInfo::produitNom).orElse("votre commande");
            notifications.notifier(part.commercantId(),
                    "Votre demande de remboursement de " + r.getMontant().toBigInteger()
                    + " FCFA pour « " + nomProduit + " » a été rejetée par l'administration DoGo. Motif : " + justification);
        }
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
        return remboursements.findByStatutOrderByIdAsc(StatutRemboursement.DEMANDE).stream().map(this::vue)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<RemboursementVue> pourCommercant(long commercantId) {
        List<Long> partIds = participations.participationIdsParCommercant(commercantId);
        if (partIds.isEmpty()) {
            return List.of();
        }
        List<Long> payIds = paiements.paiementIdsPourParticipations(partIds);
        if (payIds.isEmpty()) {
            return List.of();
        }
        return remboursements.findByPaiementIdInOrderByIdDesc(payIds).stream()
                .map(this::vue).toList();
    }

    // ---------------------------------------------------------------------------------- exécution

    private void executer(Remboursement r, Paiement p, Sequestre s) {
        Instant maintenant = horloge.instant();
        BigDecimal montant = r.getMontant();
        long remboursementId = r.getId();
        long paiementId = p.getId();
        ParticipationApi.ParticipationInfo part = participations.participation(p.getParticipationId()).orElseThrow();
        GroupeAchatApi.GroupeInfo g = campagne.groupe(part.groupeId()).orElseThrow();
        long portefeuillePorteurId = mouvements.portefeuilleDe(g.porteurId()).getId();
        long portefeuilleCommercantId = mouvements.portefeuilleDe(part.commercantId()).getId();
        IdentiteApi.MoyenPaiementInfo moyen = (p.getMoyenPaiementId() != null)
                ? identite.moyenPaiementDe(part.commercantId(), p.getMoyenPaiementId())
                : identite.moyenParDefaut(part.commercantId()).orElse(null);

        // 1) modifications des entités
        s.restituer(maintenant);
        p.enregistrerRemboursement(montant, maintenant);
        r.marquerExecute(maintenant);
        // 2) déblocage sur le portefeuille du porteur (restitution du séquestre)
        if (portefeuilles.debloquer(portefeuillePorteurId, montant) != 1) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-41", "Solde bloqué du courtier insuffisant pour ce remboursement");
        }
        // 3) Crédit direct du portefeuille du Commerçant (la somme y retourne et y reste pour ses futurs achats)
        portefeuilles.crediterDisponible(portefeuilleCommercantId, montant);

        // 4) effets externes, journal et trace
        String reference = "REMB-" + remboursementId;
        mouvements.enregistrer(paiementId, portefeuilleCommercantId, TypeMouvement.REMBOURSEMENT, montant, reference);
        audit.tracer(null, "REMBOURSEMENT_EXECUTE", "paiement=" + paiementId, "montant=" + montant);
        String numero = (moyen != null) ? moyen.numero() : identite.acteur(part.commercantId()).map(IdentiteApi.ActeurInfo::telephone).orElse("N/A");
        String operateur = (moyen != null) ? moyen.operateur() : "ORANGE_MONEY";
        passerelle.rembourser(reference, numero, operateur, montant);
        String nomProduit = (g.produitNom() != null && !g.produitNom().isBlank()) ? g.produitNom() : "votre commande";
        notifications.notifier(part.commercantId(),
                "Votre remboursement de " + montant.toBigInteger() + " FCFA pour la commande « " + nomProduit
                + " » a été validé avec succès par l'administration DoGo et crédité sur votre portefeuille d'achats.");
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
        // FINANCE, ou TECHNIQUE (super-administrateur, qui détient toutes les permissions)
        String role = identite.roleAdministratif(adminId).orElse(null);
        if (!"FINANCE".equals(role) && !"TECHNIQUE".equals(role)) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-60",
                    "Seul un administrateur FINANCE ou TECHNIQUE traite les remboursements");
        }
    }

    private RemboursementVue vue(Remboursement r) {
        Paiement p = paiements.findById(r.getPaiementId()).orElse(null);
        Long partId = p != null ? p.getParticipationId() : null;
        Long grpId = null;
        String prod = null;
        if (partId != null) {
            ParticipationApi.ParticipationInfo part = participations.participation(partId).orElse(null);
            if (part != null) {
                grpId = part.groupeId();
                prod = campagne.groupe(part.groupeId()).map(GroupeAchatApi.GroupeInfo::produitNom).orElse(null);
            }
        }
        return new RemboursementVue(r.getId(), r.getPaiementId(), partId, grpId, prod,
                r.getMontant(), r.getStatut().name(), r.getMotif().name(), r.getDateDemande());
    }
}

