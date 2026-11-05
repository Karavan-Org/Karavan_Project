package ml.dogo.logistique.application;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.logistique.domain.StatutCommande;
import ml.dogo.logistique.domain.StatutExpedition;
import ml.dogo.logistique.persistence.Commande;
import ml.dogo.logistique.persistence.CommandeRepository;
import ml.dogo.logistique.persistence.EvenementLogistique;
import ml.dogo.logistique.persistence.EvenementLogistiqueRepository;
import ml.dogo.logistique.persistence.Expedition;
import ml.dogo.logistique.persistence.ExpeditionRepository;
import ml.dogo.logistique.persistence.PointRetrait;
import ml.dogo.logistique.persistence.PointRetraitRepository;
import ml.dogo.logistique.persistence.QrColis;
import ml.dogo.logistique.persistence.QrColisRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gestion du cycle de vie des QR Colis (KVC.) : génération, régénération, étiquette ZXing
 * et validation de l'arrivée du convoi à destination.
 */
@Service
public class QrColisService {

    public record QrColisVue(long id, long expeditionId, String token, String codeCourt, String statut,
                             Instant expiration, Instant dateCreation, Instant dateUtilisation) {
    }

    public record QrColisHistoriqueVue(long id, long expeditionId, String statut,
                                       Instant expiration, Instant dateCreation, Instant dateUtilisation) {
    }

    public record ColisArriveeVue(long expeditionId, String reference, String statut, Instant date,
                                  String mode, int commandesImpactees, String message) {
    }

    private final QrColisRepository qrColisRepository;
    private final ExpeditionRepository expeditions;
    private final CommandeRepository commandes;
    private final EvenementLogistiqueRepository evenements;
    private final PointRetraitRepository points;
    private final RetraitService retraits;
    private final GroupeAchatApi groupes;
    private final ParticipationApi participations;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final QrSecuriteService qrSecurite;
    private final Clock horloge;
    private final int expirationJours;

    public QrColisService(QrColisRepository qrColisRepository, ExpeditionRepository expeditions,
                           CommandeRepository commandes, EvenementLogistiqueRepository evenements,
                           PointRetraitRepository points, RetraitService retraits, GroupeAchatApi groupes,
                           ParticipationApi participations, AuditApi audit, NotificationApi notifications,
                           QrSecuriteService qrSecurite, Clock horloge,
                           @Value("${qr.colis.expiration-jours:45}") int expirationJours) {
        this.qrColisRepository = qrColisRepository;
        this.expeditions = expeditions;
        this.commandes = commandes;
        this.evenements = evenements;
        this.points = points;
        this.retraits = retraits;
        this.groupes = groupes;
        this.participations = participations;
        this.audit = audit;
        this.notifications = notifications;
        this.qrSecurite = qrSecurite;
        this.horloge = horloge;
        this.expirationJours = expirationJours > 0 ? expirationJours : 45;
    }

    /**
     * Crée ou récupère le QR colis actif d'une expédition.
     */
    @Transactional
    public QrColisVue obtenirOuCreer(long expeditionId) {
        Expedition exp = expeditions.findById(expeditionId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Expédition", expeditionId));

        Optional<QrColis> existant = qrColisRepository.findByExpeditionIdAndStatut(expeditionId, "ACTIF");
        if (existant.isPresent()) {
            QrColis qr = existant.get();
            String tokenClair = qrSecurite.dechiffrer(qr.getTokenChiffre());
            return new QrColisVue(qr.getId(), exp.getId(), tokenClair, "********", qr.getStatut(),
                    qr.getExpiration(), qr.getDateCreation(), qr.getDateUtilisation());
        }

        return creerNouveauQrColis(exp);
    }

    /**
     * Régénère un nouveau QR colis en invalidant l'ancien (un seul actif à la fois).
     */
    @Transactional
    public QrColisVue regenerer(UtilisateurCourant acteur, long expeditionId) {
        Expedition exp = expeditions.findById(expeditionId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Expédition", expeditionId));

        if (!acteur.estAdministrateur()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-SEC",
                    "Seul un administrateur peut régénérer un QR colis");
        }

        qrColisRepository.annulerActifsDeExpedition(expeditionId);
        QrColisVue nouveau = creerNouveauQrColis(exp);
        audit.tracer(acteur.id(), "QR_COLIS_REGENERE", "expedition=" + expeditionId, "statut=ACTIF");
        return nouveau;
    }

    private QrColisVue creerNouveauQrColis(Expedition exp) {
        Instant maintenant = horloge.instant();
        Instant expiration = maintenant.plus(Duration.ofDays(expirationJours));

        String token = qrSecurite.genererJeton(QrSecuriteService.PREFIXE_COLIS);
        String codeCourt = qrSecurite.genererCodeCourt();

        String tokenHash = qrSecurite.hasher(token);
        String codeCourtHash = qrSecurite.hasher(codeCourt);
        String tokenChiffre = qrSecurite.chiffrer(token);

        QrColis qr = qrColisRepository.save(new QrColis(exp.getId(), tokenHash, tokenChiffre, codeCourtHash,
                expiration, maintenant));

        return new QrColisVue(qr.getId(), exp.getId(), token, codeCourt, qr.getStatut(), expiration,
                maintenant, null);
    }

    /**
     * Génère l'image PNG du QR colis pour impression sur l'étiquette logistique.
     */
    @Transactional(readOnly = true)
    public byte[] genererImageEtiquetteQr(long expeditionId, int width, int height) {
        Expedition exp = expeditions.findById(expeditionId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Expédition", expeditionId));

        QrColis qr = qrColisRepository.findByExpeditionIdAndStatut(expeditionId, "ACTIF")
                .or(() -> qrColisRepository.findFirstByExpeditionIdOrderByDateCreationDesc(expeditionId))
                .orElseGet(() -> {
                    // Création à la volée si inexistant
                    QrColisVue vue = obtenirOuCreer(expeditionId);
                    return qrColisRepository.findById(vue.id()).orElseThrow();
                });

        String contenu = qrSecurite.dechiffrer(qr.getTokenChiffre());
        if (contenu == null || contenu.isBlank()) {
            contenu = exp.getReference();
        }

        return qrSecurite.genererImageQrPng(contenu, width > 0 ? width : 300, height > 0 ? height : 300);
    }

    /**
     * Validation au scan du QR colis ou par saisie du code court d'urgence.
     * Atomicité stricte : UPDATE ... WHERE statut = 'ACTIF' pour éviter les doubles validations simultanées.
     */
    @Transactional
    public ColisArriveeVue validerArrivee(UtilisateurCourant acteur, String jetonOuCodeCourt, String ip) {
        if (!acteur.estAdministrateur()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-COLIS",
                    "Seul le personnel autorisé ou un administrateur peut valider l'arrivée d'un colis");
        }

        qrSecurite.controlerTentatives("agent:" + acteur.id());
        if (ip != null) {
            qrSecurite.controlerTentatives("ip:" + ip);
        }

        String valeurNettoyee = qrSecurite.nettoyerJeton(jetonOuCodeCourt);
        if (valeurNettoyee == null || valeurNettoyee.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-COLIS", "Le jeton ou code court est obligatoire");
        }

        // Vérification stricte du préfixe : refuser si un QR retrait KVR est présenté
        qrSecurite.verifierTypeColis(valeurNettoyee);

        String hash = qrSecurite.hasher(valeurNettoyee);
        boolean parCodeCourt = valeurNettoyee.matches("^\\d{8}$");

        QrColis qr = (parCodeCourt ? qrColisRepository.findByCodeCourtHash(hash) : qrColisRepository.findByTokenHash(hash))
                .or(() -> qrColisRepository.findByCodeCourtHash(hash))
                .orElseThrow(() -> {
                    qrSecurite.enregistrerTentative("agent:" + acteur.id());
                    return new ErreurMetier(CodeErreur.CODE_RETRAIT_INVALIDE, "RG-COLIS", "QR colis ou code court inconnu");
                });

        Instant maintenant = horloge.instant();

        if (qr.isUtilise()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-COLIS",
                    "Ce colis a déjà été validé à l'arrivée le " + (qr.getDateUtilisation() != null ? qr.getDateUtilisation() : "précédemment"));
        }

        if (qr.isAnnule()) {
            throw new ErreurMetier(CodeErreur.CODE_RETRAIT_INVALIDE, "RG-COLIS",
                    "Ce QR colis a été annulé suite à une régénération");
        }

        if (maintenant.isAfter(qr.getExpiration())) {
            throw new ErreurMetier(CodeErreur.CODE_RETRAIT_INVALIDE, "RG-COLIS",
                    "Ce QR colis est expiré depuis le " + qr.getExpiration());
        }

        // Mise à jour atomique
        int modifie = qrColisRepository.consommer(qr.getId(), maintenant, acteur.id());
        if (modifie != 1) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-COLIS",
                    "Ce colis a déjà été validé simultanément par un autre scan");
        }

        Expedition exp = expeditions.findById(qr.getExpeditionId())
                .orElseThrow(() -> ErreurMetier.nonTrouve("Expédition", qr.getExpeditionId()));

        if (exp.getStatut() != StatutExpedition.ARRIVE) {
            exp.marquerArrive();
            evenements.save(new EvenementLogistique(exp.getId(), "ARRIVÉ À BAMAKO", maintenant, "Bamako"));
        }

        int impactees = 0;
        if (exp.getGroupeId() != null) {
            long groupeId = exp.getGroupeId();
            List<Commande> commandesDuGroupe = commandes.findByGroupeIdOrderByIdAsc(groupeId);

            PointRetrait pointDefaut = points.findAll().stream().findFirst().orElse(null);

            for (Commande c : commandesDuGroupe) {
                if (c.getStatut() == StatutCommande.EXPEDIEE || c.getStatut() == StatutCommande.PREPAREE) {
                    c.changerStatut(StatutCommande.ARRIVEE);
                }
                if (c.getStatut() == StatutCommande.ARRIVEE) {
                    c.changerStatut(StatutCommande.EN_ATTENTE_RETRAIT);
                    if (c.getPointRetraitId() == null && pointDefaut != null) {
                        c.affecterPointRetrait(pointDefaut.getId());
                    }
                    String nomPoint = c.getPointRetraitId() != null
                            ? points.findById(c.getPointRetraitId()).map(PointRetrait::getNom).orElse("Dépôt principal")
                            : "Dépôt principal";
                    retraits.genererCode(c, nomPoint);
                    impactees++;
                }
            }

            // Notification aux destinataires du groupe
            GroupeAchatApi.GroupeInfo g = groupes.groupe(groupeId).orElse(null);
            if (g != null) {
                if ("EN_EXPEDITION".equals(g.statut())) {
                    groupes.transitionner(groupeId, "LIVRE", "SYSTEME_QR_COLIS");
                }
                String notif = "Expédition " + exp.getReference() + " : Votre colis est arrivé à Bamako ! Les commandes sont prêtes à être retirées.";
                Set<Long> destinataires = new LinkedHashSet<>();
                participations.confirmees(groupeId).forEach(p -> destinataires.add(p.commercantId()));
                destinataires.add(g.grossisteId());
                destinataires.add(g.porteurId());
                destinataires.forEach(id -> notifications.notifier(id, notif));
            }
        }

        audit.tracer(acteur.id(), "COLIS_ARRIVEE_VALIDEE", "expedition=" + exp.getId(),
                "reference=" + exp.getReference() + " commandesPrêtes=" + impactees);

        String mode = parCodeCourt ? "CODE_COURT" : "QR_SCAN";
        return new ColisArriveeVue(exp.getId(), exp.getReference(), exp.getStatut().name(),
                maintenant, mode, impactees, "Arrivée du colis validée avec succès. " + impactees + " commande(s) prête(s) à être retirée(s).");
    }

    public List<QrColisHistoriqueVue> historiqueExpedition(long expeditionId) {
        return qrColisRepository.findByExpeditionIdOrderByDateCreationDesc(expeditionId).stream()
                .map(q -> new QrColisHistoriqueVue(q.getId(), q.getExpeditionId(), q.getStatut(),
                        q.getExpiration(), q.getDateCreation(), q.getDateUtilisation()))
                .toList();
    }
}
