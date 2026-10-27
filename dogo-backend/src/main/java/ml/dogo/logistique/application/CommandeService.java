package ml.dogo.logistique.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.groupeachat.api.Evenements;
import ml.dogo.catalogue.api.CatalogueApi;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.logistique.domain.StatutCommande;
import ml.dogo.logistique.persistence.Commande;
import ml.dogo.logistique.persistence.CommandeRepository;
import ml.dogo.logistique.persistence.PointRetrait;
import ml.dogo.logistique.persistence.PointRetraitRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Commandes et acheminement (RG-44 à RG-52). Les opérations d'acheminement portent sur un groupe entier : le Courtier
 * prépare, expédie, puis confirme l'arrivée au point de retrait ; un administrateur valide la réception au dépôt.
 * Chaque opération verrouille d'abord toutes les commandes du groupe (dans l'ordre des identifiants), puis, au besoin,
 * demande le changement d'état du groupe au moteur d'états du module campagne.
 */
@Service
public class CommandeService {

    public record PointVue(long id, String nom, String adresse, String quartier, String lienGoogleMap) {
    }

    /** {@code commercantId} et {@code commercantNom} renseignés selon les droits de consultation. */
    public record CommandeVue(long id, long participationId, long groupeId, String produit, String sku, String taille,
                              String couleur, int quantite, String statut, PointVue pointRetrait, Long commercantId,
                              String commercantNom, Instant dateCreation, String photoUrl) {
    }

    private final CommandeRepository commandes;
    private final PointRetraitRepository points;
    private final RetraitService retraits;
    private final GroupeAchatApi campagne;
    private final ParticipationApi participations;
    private final CatalogueApi catalogue;
    private final IdentiteApi identite;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final Clock horloge;

    public CommandeService(CommandeRepository commandes, PointRetraitRepository points, RetraitService retraits,
                           GroupeAchatApi campagne, ParticipationApi participations, CatalogueApi catalogue,
                           IdentiteApi identite, AuditApi audit, NotificationApi notifications, Clock horloge) {
        this.commandes = commandes;
        this.points = points;
        this.retraits = retraits;
        this.campagne = campagne;
        this.participations = participations;
        this.catalogue = catalogue;
        this.identite = identite;
        this.audit = audit;
        this.notifications = notifications;
        this.horloge = horloge;
    }

    // ---------------------------------------------------------------------- création (RG-44)

    /**
     * RG-44 : quand l'objectif est atteint, chaque participation confirmée devient une commande. S'exécute dans la
     * transaction qui a fait passer le groupe à OBJECTIF_ATTEINT : les deux réussissent ou échouent ensemble.
     */
    @EventListener
    @Transactional(propagation = Propagation.MANDATORY)
    public void surObjectifAtteint(Evenements.ObjectifAtteint evenement) {
        long groupeId = evenement.groupeId();
        Instant maintenant = horloge.instant();
        int creees = 0;
        for (ParticipationApi.ParticipationInfo p : participations.confirmees(groupeId)) {
            if (commandes.existsByParticipationId(p.id())) {
                continue;
            }
            commandes.save(new Commande(p.id(), groupeId, p.commercantId(), p.quantite(), maintenant));
            notifications.notifier(p.commercantId(),
                    "Le groupe #" + groupeId + " a atteint son objectif : votre commande est créée. Nous vous prévenons à chaque étape.");
            creees++;
        }
        GroupeAchatApi.GroupeInfo g = campagne.groupe(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        audit.tracer(null, "COMMANDES_CREEES", "groupe=" + groupeId, creees + " commande(s)");
        notifications.notifier(g.porteurId(), "Groupe #" + groupeId + " : " + creees
                + " commande(s) créée(s). Vous pouvez commencer la préparation.");
        notifications.notifier(g.grossisteId(), "Groupe #" + groupeId + " (" + g.produitNom() + ") : " + creees
                + " commande(s) à préparer.");
    }

    // ---------------------------------------------------------------------- acheminement

    /** RG-50 : le Courtier passe les commandes du groupe à PREPAREE (groupe à l'état OBJECTIF_ATTEINT). */
    @Transactional
    public List<CommandeVue> preparer(UtilisateurCourant acteur, long groupeId) {
        GroupeAchatApi.GroupeInfo g = groupeDuCourtier(acteur, groupeId, "OBJECTIF_ATTEINT");
        List<Commande> duGroupe = actives(commandes.verrouillerDuGroupe(groupeId), groupeId);
        duGroupe.forEach(c -> c.changerStatut(StatutCommande.PREPAREE));
        audit.tracer(acteur.id(), "COMMANDES_PREPAREES", "groupe=" + groupeId, duGroupe.size() + " commande(s)");
        return duGroupe.stream().map(c -> vue(c, g, Vision.COMPLETE)).toList();
    }

    /**
     * RG-50 : expédition. Toutes les commandes doivent être préparées ; elles passent à EXPEDIEE et le groupe à
     * EN_EXPEDITION (mise à jour conditionnelle : si quelqu'un l'a déjà fait évoluer, tout est annulé).
     */
    @Transactional
    public List<CommandeVue> expedier(UtilisateurCourant acteur, long groupeId) {
        GroupeAchatApi.GroupeInfo g = groupeDuCourtier(acteur, groupeId, "OBJECTIF_ATTEINT");
        List<Commande> duGroupe = actives(commandes.verrouillerDuGroupe(groupeId), groupeId);
        if (duGroupe.stream().anyMatch(c -> c.getStatut() != StatutCommande.PREPAREE)) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-50",
                    "Toutes les commandes doivent être préparées avant l'expédition");
        }
        duGroupe.forEach(c -> c.changerStatut(StatutCommande.EXPEDIEE));
        campagne.transitionner(groupeId, "EN_EXPEDITION", (acteur.estAdministrateur() ? "ADMIN:" : "COURTIER:") + acteur.id());
        audit.tracer(acteur.id(), "GROUPE_EXPEDIE", "groupe=" + groupeId, duGroupe.size() + " commande(s)");
        duGroupe.forEach(c -> notifications.notifier(c.getCommercantId(),
                "Votre commande #" + c.getId() + " (" + g.produitNom() + ") est expédiée."));
        return duGroupe.stream().map(c -> vue(c, g, Vision.COMPLETE)).toList();
    }

    /** RG-52 : un administrateur valide la réception des colis au dépôt : commandes ARRIVEE, groupe LIVRE. */
    @Transactional
    public List<CommandeVue> validerReception(UtilisateurCourant acteur, long groupeId) {
        GroupeAchatApi.GroupeInfo g = campagne.groupe(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        List<Commande> duGroupe = actives(commandes.verrouillerDuGroupe(groupeId), groupeId);
        if (duGroupe.stream().anyMatch(c -> c.getStatut() != StatutCommande.EXPEDIEE)) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-52",
                    "Le groupe n'est pas en cours d'expédition");
        }
        duGroupe.forEach(c -> c.changerStatut(StatutCommande.ARRIVEE));
        campagne.transitionner(groupeId, "LIVRE", "ADMIN:" + acteur.id());
        audit.tracer(acteur.id(), "RECEPTION_VALIDEE", "groupe=" + groupeId, duGroupe.size() + " commande(s)");
        notifications.notifier(g.porteurId(), "Groupe #" + groupeId
                + " : la réception des colis est validée. Confirmez leur arrivée au point de retrait.");
        duGroupe.forEach(c -> notifications.notifier(c.getCommercantId(), "Votre commande #" + c.getId() + " ("
                + g.produitNom() + ") est réceptionnée au dépôt dɔgɔ. Vous recevrez votre code de retrait très bientôt."));
        return duGroupe.stream().map(c -> vue(c, g, Vision.COMPLETE)).toList();
    }

    /**
     * RG-53 : le Courtier confirme que les colis sont arrivés au point de retrait. Chaque commande passe à
     * EN_ATTENTE_RETRAIT et reçoit son code (QR + PIN) ; le PIN part par SMS vers le Commerçant.
     */
    @Transactional
    public List<CommandeVue> confirmerArriveeAuPoint(UtilisateurCourant acteur, long groupeId, long pointRetraitId) {
        GroupeAchatApi.GroupeInfo g = groupeDuCourtier(acteur, groupeId, "LIVRE");
        PointRetrait point = points.findById(pointRetraitId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Point de retrait", pointRetraitId));
        List<Commande> duGroupe = actives(commandes.verrouillerDuGroupe(groupeId), groupeId);
        if (duGroupe.stream().anyMatch(c -> c.getStatut() != StatutCommande.ARRIVEE)) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-53",
                    "Les colis doivent d'abord être réceptionnés au dépôt par un administrateur");
        }
        for (Commande c : duGroupe) {
            c.changerStatut(StatutCommande.EN_ATTENTE_RETRAIT);
            c.affecterPointRetrait(point.getId());
            retraits.genererCode(c, point.getNom(), point.getLienGoogleMap(), point.getAdresse());
        }
        audit.tracer(acteur.id(), "ARRIVEE_POINT_RETRAIT", "groupe=" + groupeId,
                "point=" + point.getId() + ", " + duGroupe.size() + " commande(s)");
        return duGroupe.stream().map(c -> vue(c, g, Vision.COMPLETE)).toList();
    }

    /**
     * L'administrateur valide l'arrivée au dépôt et envoie la notification contenant la localisation Google Maps
     * prélevée directement sur le point de retrait configuré.
     */
    @Transactional
    public List<CommandeVue> notifierArriveeDepot(UtilisateurCourant acteur, long groupeId, long pointRetraitId) {
        if (!acteur.estAdministrateur()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, null, "Seul un administrateur peut valider et notifier l'arrivée au dépôt");
        }
        GroupeAchatApi.GroupeInfo g = campagne.groupe(groupeId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        PointRetrait point = points.findById(pointRetraitId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Point de retrait", pointRetraitId));

        List<Commande> duGroupe = actives(commandes.verrouillerDuGroupe(groupeId), groupeId);

        for (Commande c : duGroupe) {
            c.affecterPointRetrait(point.getId());
            if (c.getStatut() == StatutCommande.EXPEDIEE) {
                c.changerStatut(StatutCommande.ARRIVEE);
            }
        }

        if ("EN_EXPEDITION".equals(g.statut())) {
            campagne.transitionner(groupeId, "LIVRE", "ADMIN:" + acteur.id());
        }

        String lienLocalisation = (point.getLienGoogleMap() != null && !point.getLienGoogleMap().isBlank())
                ? point.getLienGoogleMap()
                : ("https://maps.google.com/?q=" + point.getAdresse().replace(" ", "+"));

        String messageNotif = "Colis arrivés au dépôt " + point.getNom() + " (" + point.getAdresse() + "). "
                + "Localisation Google Maps : " + lienLocalisation + " . "
                + "Votre code de retrait vous parviendra une fois le colis déchargé.";

        java.util.Set<Long> commercantsNotifies = new java.util.HashSet<>();
        for (Commande c : duGroupe) {
            if (!commercantsNotifies.contains(c.getCommercantId())) {
                notifications.notifier(c.getCommercantId(), messageNotif);
                commercantsNotifies.add(c.getCommercantId());
            }
        }

        audit.tracer(acteur.id(), "NOTIFICATION_DEPOT_ENVOYEE", "groupe=" + groupeId,
                "point=" + point.getId() + " (" + point.getNom() + "), " + duGroupe.size() + " commande(s)");

        return duGroupe.stream().map(c -> vue(c, g, Vision.COMPLETE)).toList();
    }

    /** Permet au porteur ou au grossiste de notifier tous les acheteurs du groupe. */
    @Transactional
    public void notifierAcheteurs(UtilisateurCourant acteur, long groupeId, String message) {
        GroupeAchatApi.GroupeInfo g = campagne.groupe(groupeId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        boolean autorise = acteur.estAdministrateur() || g.porteurId() == acteur.id() || g.grossisteId() == acteur.id();
        if (!autorise) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-71", "Vous ne pouvez pas notifier les acheteurs de ce groupe");
        }

        List<Long> acheteurs = participations.actives(groupeId).stream()
                .map(ParticipationApi.ParticipationInfo::commercantId)
                .distinct()
                .toList();

        for (Long cId : acheteurs) {
            notifications.notifier(cId, "Groupe #" + groupeId + " (" + g.produitNom() + ") : " + message);
        }
        audit.tracer(acteur.id(), "NOTIFICATION_GROUPE_ENVOYEE", "groupe=" + groupeId, acheteurs.size() + " acheteur(s) notifié(s)");
    }

    // ---------------------------------------------------------------------- consultation

    /** Commandes du Commerçant connecté (vide pour les autres profils : ils passent par les commandes d'un groupe). */
    @Transactional(readOnly = true)
    public List<CommandeVue> mesCommandes(long commercantId) {
        return commandes.findByCommercantIdOrderByIdDesc(commercantId).stream()
                .map(c -> vue(c, groupeDe(c), Vision.COMPLETE)).toList();
    }

    /** Commandes d'un groupe : accessible au courtier, grossiste et administrateur. */
    @Transactional(readOnly = true)
    public List<CommandeVue> duGroupe(UtilisateurCourant acteur, long groupeId) {
        GroupeAchatApi.GroupeInfo g = campagne.groupe(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        Vision vision = visionSur(acteur, g);
        List<Commande> list = commandes.findByGroupeIdOrderByIdAsc(groupeId);
        if (!list.isEmpty()) {
            return list.stream().map(c -> vue(c, g, vision)).toList();
        }
        // Groupe sans commande formelle créée (en cours de constitution) : on liste les participations actives
        return participations.actives(groupeId).stream().map(p -> vueParticipation(p, g, vision)).toList();
    }

    @Transactional(readOnly = true)
    public CommandeVue detail(UtilisateurCourant acteur, long commandeId) {
        Commande c = commandes.findById(commandeId).orElseThrow(() -> ErreurMetier.nonTrouve("Commande", commandeId));
        GroupeAchatApi.GroupeInfo g = groupeDe(c);
        if (c.getCommercantId() == acteur.id()) {
            return vue(c, g, Vision.COMPLETE);
        }
        return vue(c, g, visionSur(acteur, g));
    }

    // ---------------------------------------------------------------------- utilitaires

    private enum Vision { COMPLETE, SANS_ACHETEUR }

    private Vision visionSur(UtilisateurCourant acteur, GroupeAchatApi.GroupeInfo g) {
        if (acteur.estAdministrateur() || g.porteurId() == acteur.id() || g.grossisteId() == acteur.id()) {
            return Vision.COMPLETE;
        }
        throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-71", "Vous n'avez pas accès à ces commandes");
    }

    private GroupeAchatApi.GroupeInfo groupeDuCourtier(UtilisateurCourant acteur, long groupeId, String statutRequis) {
        GroupeAchatApi.GroupeInfo g = campagne.groupe(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        boolean autorise = g.porteParGrossiste() ? acteur.estAdministrateur() : g.courtierId() == acteur.id();
        if (!autorise) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-50", "Seul le courtier de ce groupe peut faire avancer ses commandes");
        }
        if (!statutRequis.equals(g.statut())) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-50",
                    "Opération impossible : le groupe est à l'état " + g.statut() + " (attendu : " + statutRequis + ")");
        }
        return g;
    }

    /** Commandes à faire avancer : celles qui ne sont pas annulées. Il doit y en avoir au moins une. */
    private List<Commande> actives(List<Commande> verrouillees, long groupeId) {
        List<Commande> actives = verrouillees.stream().filter(c -> c.getStatut() != StatutCommande.ANNULEE).toList();
        if (actives.isEmpty()) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-44", "Le groupe #" + groupeId + " n'a aucune commande à traiter");
        }
        return actives;
    }

    private GroupeAchatApi.GroupeInfo groupeDe(Commande c) {
        return campagne.groupe(c.getGroupeId()).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", c.getGroupeId()));
    }

    private CommandeVue vue(Commande c, GroupeAchatApi.GroupeInfo g, Vision vision) {
        Optional<ParticipationApi.ParticipationInfo> p = participations.participation(c.getParticipationId());
        Optional<CatalogueApi.VarianteInfo> v = p.flatMap(pi -> catalogue.variante(pi.varianteId()));
        PointVue point = c.getPointRetraitId() == null ? null
                : points.findById(c.getPointRetraitId()).map(x -> new PointVue(x.getId(), x.getNom(), x.getAdresse(), x.getQuartier(), x.getLienGoogleMap())).orElse(null);
        boolean avecAcheteur = vision == Vision.COMPLETE;
        String nom = avecAcheteur ? identite.acteur(c.getCommercantId()).map(IdentiteApi.ActeurInfo::nom).orElse(null) : null;
        return new CommandeVue(c.getId(), c.getParticipationId(), c.getGroupeId(), g.produitNom(),
                v.map(CatalogueApi.VarianteInfo::sku).orElse(null), v.map(CatalogueApi.VarianteInfo::taille).orElse(null),
                v.map(CatalogueApi.VarianteInfo::couleur).orElse(null), c.getQuantite(), c.getStatut().name(), point,
                avecAcheteur ? c.getCommercantId() : null, nom, c.getDateCreation(), catalogue.produit(g.produitId()).map(CatalogueApi.ProduitInfo::photoUrl).orElse(null));
    }

    private CommandeVue vueParticipation(ParticipationApi.ParticipationInfo p, GroupeAchatApi.GroupeInfo g, Vision vision) {
        Optional<CatalogueApi.VarianteInfo> v = catalogue.variante(p.varianteId());
        boolean avecAcheteur = vision == Vision.COMPLETE;
        String nom = avecAcheteur ? identite.acteur(p.commercantId()).map(IdentiteApi.ActeurInfo::nom).orElse("Boutique #" + p.commercantId()) : null;
        return new CommandeVue(p.id(), p.id(), p.groupeId(), g.produitNom(),
                v.map(CatalogueApi.VarianteInfo::sku).orElse(null), v.map(CatalogueApi.VarianteInfo::taille).orElse(null),
                v.map(CatalogueApi.VarianteInfo::couleur).orElse(null), p.quantite(), p.statut(), null,
                avecAcheteur ? p.commercantId() : null, nom, Instant.now(), catalogue.produit(g.produitId()).map(CatalogueApi.ProduitInfo::photoUrl).orElse(null));
    }
}
