package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.finance.domain.MotifRemboursement;
import ml.dogo.finance.domain.StatutPaiement;
import ml.dogo.finance.domain.TypeMouvement;
import ml.dogo.finance.persistence.Paiement;
import ml.dogo.finance.persistence.PorteFeuilleCourtierRepository;
import ml.dogo.finance.persistence.Sequestre;
import ml.dogo.finance.persistence.SequestreRepository;
import ml.dogo.finance.persistence.TransactionMobileMoney;
import ml.dogo.finance.persistence.TransactionMobileMoneyRepository;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.persistence.Verrou;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Application d'un callback Mobile Money vérifié (RG-30, RG-35, RG-36). Le statut PAYE n'est écrit qu'ici, jamais à
 * la demande d'un client ; le callback brut est conservé ; un callback déjà vu est ignoré.
 */
@Service
public class TraitementPaiement {

    public enum Resultat { TRAITE, DOUBLON, ANOMALIE }

    public record Callback(String reference, String txId, String statut, BigDecimal montant, String operateur) {
    }

    private final TransactionMobileMoneyRepository transactions;
    private final SequestreRepository sequestres;
    private final PorteFeuilleCourtierRepository portefeuilles;
    private final MouvementService mouvements;
    private final RemboursementService remboursements;
    private final ParticipationApi participations;
    private final GroupeAchatApi campagne;
    private final IdentiteApi identite;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final Verrou verrou;
    private final Clock horloge;

    public TraitementPaiement(TransactionMobileMoneyRepository transactions, SequestreRepository sequestres,
                              PorteFeuilleCourtierRepository portefeuilles, MouvementService mouvements,
                              RemboursementService remboursements, ParticipationApi participations,
                              GroupeAchatApi campagne, IdentiteApi identite, AuditApi audit,
                              NotificationApi notifications, Verrou verrou, Clock horloge) {
        this.transactions = transactions;
        this.sequestres = sequestres;
        this.portefeuilles = portefeuilles;
        this.mouvements = mouvements;
        this.remboursements = remboursements;
        this.participations = participations;
        this.campagne = campagne;
        this.identite = identite;
        this.audit = audit;
        this.notifications = notifications;
        this.verrou = verrou;
        this.horloge = horloge;
    }

    @Transactional
    public Resultat appliquer(Callback c, String corpsBrut) {
        long paiementId = lireReference(c.reference());
        Paiement p = verrou.ecriture(Paiement.class, paiementId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Paiement", c.reference()));
        if (transactions.existsByTxId(c.txId())) {
            return Resultat.DOUBLON;
        }
        Instant maintenant = horloge.instant();
        transactions.save(new TransactionMobileMoney(paiementId, c.txId(), c.operateur(), corpsBrut, maintenant));

        if (c.montant() == null || c.montant().compareTo(p.getMontant()) != 0) {
            signalerAnomalie("CALLBACK_MONTANT_INCOHERENT", paiementId, "recu=" + c.montant() + ", attendu=" + p.getMontant());
            return Resultat.ANOMALIE;
        }
        boolean succes = "SUCCES".equalsIgnoreCase(c.statut());
        boolean echec = "ECHEC".equalsIgnoreCase(c.statut());
        if (!succes && !echec) {
            signalerAnomalie("CALLBACK_STATUT_INCONNU", paiementId, "statut=" + c.statut());
            return Resultat.ANOMALIE;
        }
        StatutPaiement statut = p.getStatut();
        boolean attendu = statut == StatutPaiement.EN_ATTENTE || statut == StatutPaiement.INITIE;
        if (!attendu) {
            // Paiement expiré, déjà payé... : l'argent a peut-être bougé chez l'opérateur, un humain doit regarder.
            signalerAnomalie("CALLBACK_TARDIF_OU_DOUBLE", paiementId, "statut_local=" + statut + ", callback=" + c.statut());
            return Resultat.ANOMALIE;
        }
        if (statut == StatutPaiement.INITIE) {
            p.changerStatut(StatutPaiement.EN_ATTENTE, maintenant);
        }
        if (echec) {
            p.changerStatut(StatutPaiement.ECHOUE, maintenant);
            ParticipationApi.ParticipationInfo part = participations.participation(p.getParticipationId()).orElseThrow();
            notifications.notifier(part.commercantId(),
                    "Votre paiement de " + p.getMontant().toBigInteger() + " XOF a échoué. Vous pouvez réessayer tant que la réservation est valable.");
            return Resultat.TRAITE;
        }
        marquerPaye(p);
        return Resultat.TRAITE;
    }

    /** RG-30, RG-36, RG-40 : PAYE, séquestre, portefeuille, journal et confirmation de la participation, en une transaction. */
    private void marquerPaye(Paiement p) {
        Instant maintenant = horloge.instant();
        long paiementId = p.getId();
        BigDecimal montant = p.getMontant();
        ParticipationApi.ParticipationInfo part = participations.participation(p.getParticipationId()).orElseThrow();
        GroupeAchatApi.GroupeInfo g = campagne.groupe(part.groupeId()).orElseThrow();
        long portefeuilleId = mouvements.portefeuilleDe(g.porteurId()).getId();

        p.changerStatut(StatutPaiement.PAYE, maintenant);
        sequestres.save(new Sequestre(paiementId, montant, maintenant));
        portefeuilles.bloquer(portefeuilleId, montant);   // enregistre PAYE + séquestre, puis vide le contexte

        mouvements.enregistrer(paiementId, null, TypeMouvement.DEBIT_COMMERCANT, montant,
                "PAIEMENT-" + paiementId + "-DEBIT");
        mouvements.enregistrer(paiementId, portefeuilleId, TypeMouvement.BLOCAGE_SEQUESTRE, montant,
                "PAIEMENT-" + paiementId + "-BLOCAGE");
        audit.tracer(null, "PAIEMENT_RECU", "paiement=" + paiementId, "montant=" + montant + ", sequestre=BLOQUE");

        if (participations.confirmerApresPaiement(part.id())) {
            notifications.notifier(part.commercantId(), "Paiement reçu (" + montant.toBigInteger()
                    + " XOF) : votre place dans le groupe est confirmée. Vos fonds sont gardés en séquestre jusqu'au retrait.");
        } else {
            // Réservation expirée ou annulée, ou groupe fermé pendant le paiement : on rend l'argent tout de suite.
            MotifRemboursement motif = campagne.groupe(part.groupeId()).map(GroupeAchatApi.GroupeInfo::ouvert).orElse(false)
                    ? MotifRemboursement.ANNULATION_CLIENT : MotifRemboursement.ECHEC_GROUPE;
            remboursements.demander(paiementId, motif, null);
        }
    }

    private void signalerAnomalie(String code, long paiementId, String detail) {
        audit.tracer(null, code, "paiement=" + paiementId, detail);
        for (Long admin : identite.administrateursActifs()) {
            notifications.notifier(admin, "Anomalie de paiement " + code + " sur le paiement #" + paiementId + " : " + detail);
        }
    }

    private static long lireReference(String reference) {
        if (reference != null && reference.startsWith("DOGO-")) {
            try {
                return Long.parseLong(reference.substring(5));
            } catch (NumberFormatException e) {
                // traité ci-dessous
            }
        }
        throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-35", "Référence de paiement inconnue : " + reference);
    }
}

