package ml.dogo.groupeachat.application;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.domain.CalculPrix;
import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.groupeachat.persistence.ConditionCommerciale;
import ml.dogo.groupeachat.persistence.ConditionCommercialeRepository;
import ml.dogo.groupeachat.persistence.GrilleTarifaire;
import ml.dogo.groupeachat.persistence.GrilleTarifaireRepository;
import ml.dogo.groupeachat.persistence.Pays;
import ml.dogo.groupeachat.persistence.PaysRepository;
import ml.dogo.groupeachat.persistence.GroupeAchat;
import ml.dogo.groupeachat.persistence.GroupeAchatRepository;
import ml.dogo.groupeachat.persistence.EtapeAcheminement;
import ml.dogo.groupeachat.persistence.EtapeAcheminementRepository;
import ml.dogo.groupeachat.persistence.TransitionStatutGroupeRepository;
import ml.dogo.groupeachat.persistence.ValidationGroupe;
import ml.dogo.groupeachat.persistence.ValidationGroupeRepository;
import ml.dogo.catalogue.api.CatalogueApi;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Cycle de vie des groupes d'achat : création, validation, publication, annulation, clôture (RG-16 à RG-25). */
@Service
public class GroupeService {

    /**
     * Politique d'annulation de la plateforme (RG-24) : imposée aux groupes portés par un grossiste, qui ne peut ni
     * la modifier ni la supprimer.
     */
    public static final String POLITIQUE_ANNULATION_PLATEFORME = "Annulation possible tant que l'objectif n'est pas "
            + "atteint ; remboursement intégral si le groupe est annulé ou n'atteint pas son objectif.";

    public record Demande(String titre, Long produitId, Integer quantiteCible, Instant dateLimite, BigDecimal marchandise,
                          BigDecimal transport, BigDecimal douane, BigDecimal autres, Integer delaiLivraisonJours,
                          String politiqueAnnulation, Integer quantiteMinParCommercant, String paysOrigineCode) {
    }

    public record VarianteVue(long id, String sku, String taille, String couleur) {
    }

    public record ProduitVue(long id, String nom, String description, String paysOrigine, String categorie,
                             String photoUrl, List<VarianteVue> variantes) {
    }

    public record ActeurVue(long id, String nom) {
    }

    public record GrilleVue(BigDecimal marchandise, BigDecimal transport, BigDecimal fraisPlateforme, BigDecimal douane,
                            BigDecimal autres, String devise) {
    }

    public record ConditionsVue(int delaiLivraisonJours, String politiqueAnnulation, int quantiteMinParCommercant) {
    }

    /** {@code courtier} est nul pour un groupe porté par le grossiste ({@code porteParGrossiste}). */
    public record GroupeVue(long id, String titre, String statut, ProduitVue produit, ActeurVue courtier,
                            ActeurVue grossiste, boolean porteParGrossiste, int quantiteCible, int quantiteConfirmee, int quantiteReservee, int quantiteRestante,
                            BigDecimal prixUnitaire, GrilleVue grille, ConditionsVue conditions, Instant dateOuverture,
                            Instant dateLimite, boolean disponibiliteValidee, String paysOrigineCode, String paysOrigineNom) {
    }

    public record TransitionVue(String ancien, String nouveau, Instant date, String auteur) {
    }

    public record EtapeVue(long id, String etape, String commentaire, Instant date) {
    }

    private final GroupeAchatRepository groupes;
    private final EtapeAcheminementRepository etapes;
    private final GrilleTarifaireRepository grilles;
    private final ConditionCommercialeRepository conditions;
    private final TransitionStatutGroupeRepository transitions;
    private final ValidationGroupeRepository validations;
    private final MoteurEtatsGroupe moteur;
    private final CatalogueApi catalogue;
    private final IdentiteApi identite;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final DogoProperties proprietes;
    private final Clock horloge;
    private final PaysRepository paysRepository;
    private final PaysService paysService;

    @org.springframework.beans.factory.annotation.Autowired
    public GroupeService(GroupeAchatRepository groupes, GrilleTarifaireRepository grilles,
                         ConditionCommercialeRepository conditions, TransitionStatutGroupeRepository transitions,
                         ValidationGroupeRepository validations, MoteurEtatsGroupe moteur, CatalogueApi catalogue,
                         IdentiteApi identite, AuditApi audit, NotificationApi notifications,
                         DogoProperties proprietes, Clock horloge, EtapeAcheminementRepository etapes,
                         PaysRepository paysRepository, PaysService paysService) {
        this.groupes = groupes;
        this.etapes = etapes;
        this.grilles = grilles;
        this.conditions = conditions;
        this.transitions = transitions;
        this.validations = validations;
        this.moteur = moteur;
        this.catalogue = catalogue;
        this.identite = identite;
        this.audit = audit;
        this.notifications = notifications;
        this.proprietes = proprietes;
        this.horloge = horloge;
        this.paysRepository = paysRepository;
        this.paysService = paysService != null ? paysService : new PaysService(paysRepository);
    }

    public GroupeService(GroupeAchatRepository groupes, GrilleTarifaireRepository grilles,
                         ConditionCommercialeRepository conditions, TransitionStatutGroupeRepository transitions,
                         ValidationGroupeRepository validations, MoteurEtatsGroupe moteur, CatalogueApi catalogue,
                         IdentiteApi identite, AuditApi audit, NotificationApi notifications,
                         DogoProperties proprietes, Clock horloge, EtapeAcheminementRepository etapes,
                         PaysRepository paysRepository) {
        this(groupes, grilles, conditions, transitions, validations, moteur, catalogue, identite, audit, notifications,
                proprietes, horloge, etapes, paysRepository, new PaysService(paysRepository));
    }

    // ------------------------------------------------------------- création / modification

    /**
     * RG-16, RG-17, RG-20 : un Courtier validé crée un brouillon avec une grille tarifaire complète.
     * Un Grossiste validé peut aussi monter un groupe sur l'un de ses propres produits : il en est alors le porteur
     * (pas de courtier) et achemine lui-même la marchandise.
     */
    @Transactional
    public GroupeVue creer(long acteurId, Demande d) {
        IdentiteApi.ActeurInfo createur = identite.exigerActif(acteurId);
        boolean parGrossiste = "GROSSISTE".equals(createur.type());
        if (!parGrossiste && !"COURTIER".equals(createur.type())) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-16",
                    "Seul un courtier ou un grossiste validé crée un groupe");
        }
        if (d.produitId() == null) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-16", "Le produit est obligatoire");
        }
        CatalogueApi.ProduitInfo produit = catalogue.produit(d.produitId())
                .orElseThrow(() -> ErreurMetier.nonTrouve("Produit", d.produitId()));
        if (parGrossiste && produit.grossisteId() != acteurId) {
            throw ErreurMetier.nonTrouve("Produit", d.produitId());
        }
        identite.exigerActif(produit.grossisteId());

        String saisiePays = d.paysOrigineCode() != null && !d.paysOrigineCode().isBlank()
                ? d.paysOrigineCode().trim()
                : (produit.paysOrigine() != null ? produit.paysOrigine().trim() : null);
        if (saisiePays == null || saisiePays.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-PAYS", "Le pays d'origine est obligatoire");
        }
        Pays pays = paysService.resoudre(saisiePays)
                .filter(Pays::isActif)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-PAYS",
                        "Pays d'origine non reconnu ou inactif : " + saisiePays));
        String codePays = pays.getCodeIso();

        Instant maintenant = horloge.instant();
        Calcul calcul = calculer(d, maintenant);
        GroupeAchat g = groupes.save(new GroupeAchat(parGrossiste ? null : acteurId, produit.grossisteId(),
                produit.id(), titre(d), codePays, calcul.quantiteCible, calcul.prixUnitaire, maintenant, d.dateLimite()));
        grilles.save(new GrilleTarifaire(g.getId(), calcul.composantes, proprietes.commission().taux()));
        conditions.save(new ConditionCommerciale(g.getId(), calcul.delai,
                parGrossiste ? POLITIQUE_ANNULATION_PLATEFORME : d.politiqueAnnulation(), calcul.minimum));
        audit.tracer(acteurId, "GROUPE_CREE", null, "groupe=" + g.getId() + ", produit=" + produit.id());
        return vue(groupes.findById(g.getId()).orElseThrow());
    }

    /** RG-17 / RG-20 : un brouillon reste modifiable ; dès qu'il est soumis, la grille est figée. */
    @Transactional
    public GroupeVue modifier(long porteurId, long groupeId, Demande d) {
        GroupeAchat g = groupeDuPorteur(porteurId, groupeId);
        if (g.getStatut() != StatutGroupe.BROUILLON) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-20",
                    "La grille tarifaire est figée : seul un brouillon peut être modifié");
        }
        String saisiePays = d.paysOrigineCode() != null && !d.paysOrigineCode().isBlank()
                ? d.paysOrigineCode().trim()
                : g.getPaysOrigineCode();
        String codePays = null;
        if (saisiePays != null && !saisiePays.isBlank()) {
            Pays pays = paysService.resoudre(saisiePays)
                    .filter(Pays::isActif)
                    .orElseThrow(() -> new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-PAYS",
                            "Pays d'origine non reconnu ou inactif : " + saisiePays));
            codePays = pays.getCodeIso();
        }
        Calcul calcul = calculer(d, horloge.instant());
        g.modifierBrouillon(titre(d), codePays, calcul.quantiteCible, calcul.prixUnitaire, d.dateLimite());
        grilles.findByGroupeId(groupeId).orElseThrow().appliquer(calcul.composantes, proprietes.commission().taux());
        conditions.findByGroupeId(groupeId).orElseThrow().appliquer(calcul.delai,
                g.estPorteParGrossiste() ? POLITIQUE_ANNULATION_PLATEFORME : d.politiqueAnnulation(), calcul.minimum);
        groupes.flush();
        return vue(groupes.findById(groupeId).orElseThrow());
    }

    // ---------------------------------------------------------------- circuit de validation

    /**
     * BROUILLON → EN_VALIDATION : le Grossiste doit maintenant valider la disponibilité (RG-18).
     * Quand le grossiste porte lui-même le groupe, sa soumission vaut attestation de disponibilité.
     */
    @Transactional
    public GroupeVue soumettre(long porteurId, long groupeId) {
        GroupeAchat g = groupeDuPorteur(porteurId, groupeId);
        if (g.estPorteParGrossiste()) {
            moteur.transitionner(groupeId, StatutGroupe.EN_VALIDATION, "GROSSISTE:" + porteurId, null);
            return validerDisponibilite(porteurId, groupeId);
        }
        moteur.transitionner(groupeId, StatutGroupe.EN_VALIDATION, "COURTIER:" + porteurId, null);
        notifications.notifier(g.getGrossisteId(),
                "Un groupe d'achat #" + groupeId + " attend la validation de la disponibilité de vos marchandises.");
        return vue(groupes.findById(groupeId).orElseThrow());
    }

    /** RG-18 (1re moitié) : le Grossiste atteste que les marchandises sont disponibles (RG-13 : stock suffisant). */
    @Transactional
    public GroupeVue validerDisponibilite(long grossisteId, long groupeId) {
        GroupeAchat g = groupes.findById(groupeId).filter(x -> x.getGrossisteId().equals(grossisteId))
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        if (g.getStatut() != StatutGroupe.EN_VALIDATION) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-18",
                    "Le groupe n'attend pas de validation de disponibilité");
        }
        long stock = catalogue.stockTotal(g.getProduitId());
        if (stock < g.getQuantiteCible()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-13",
                    "Stock insuffisant : " + stock + " disponible(s) pour une cible de " + g.getQuantiteCible());
        }
        g.validerDisponibilite();
        audit.tracer(grossisteId, "GROUPE_DISPONIBILITE_VALIDEE", null, "groupe=" + groupeId);
        for (Long admin : identite.administrateursActifs()) {
            notifications.notifier(admin, "Le groupe #" + groupeId + " est prêt pour l'autorisation de publication.");
        }
        groupes.flush();
        return vue(groupes.findById(groupeId).orElseThrow());
    }

    /** RG-18 (2e moitié) : un Administrateur autorise ou refuse la publication. Sans les deux validations, pas d'ouverture. */
    @Transactional
    public GroupeVue decider(long adminId, long groupeId, boolean approuve, String commentaire) {
        GroupeAchat g = groupes.findById(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        if (g.getStatut() != StatutGroupe.EN_VALIDATION) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-18", "Le groupe n'est pas en attente de validation");
        }
        Instant maintenant = horloge.instant();
        String decision = approuve ? "APPROUVE" : "REJETE";
        if (approuve) {
            if (g.getPaysOrigineCode() == null || g.getPaysOrigineCode().isBlank()) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-PAYS",
                        "Le pays d'origine doit �tre renseign� avant de publier le groupe");
            }
            if (!g.isDisponibiliteValidee()) {
                throw new ErreurMetier(CodeErreur.CONFLIT, "RG-18",
                        "Le Grossiste n'a pas encore validé la disponibilité des marchandises");
            }
            if (!g.getDateLimite().isAfter(maintenant)) {
                throw new ErreurMetier(CodeErreur.CONFLIT, "RG-17", "La date limite est déjà passée");
            }
            g.ouvrir(maintenant);
        } else {
            if (commentaire == null || commentaire.isBlank()) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-68", "Un refus doit être justifié");
            }
            g.reinitialiserDisponibilite();
        }
        validations.save(new ValidationGroupe(groupeId, adminId, decision, maintenant, commentaire));
        moteur.transitionner(groupeId, approuve ? StatutGroupe.OUVERT : StatutGroupe.BROUILLON, "ADMIN:" + adminId, null);
        audit.tracer(adminId, "GROUPE_PUBLICATION_" + decision, "groupe=" + groupeId, commentaire);
        String message = approuve
                ? "Votre groupe #" + groupeId + " est publié : les commerçants peuvent le rejoindre."
                : "Votre groupe #" + groupeId + " n'a pas été publié. Motif : " + commentaire;
        notifications.notifier(g.getPorteurId(), message);
        return vue(groupes.findById(groupeId).orElseThrow());
    }

    /** RG-24 : annulation par un Administrateur ou par le porteur du groupe (Courtier ou Grossiste), avant l'objectif atteint. */
    @Transactional
    public GroupeVue annuler(UtilisateurCourant acteur, long groupeId, String motif) {
        GroupeAchat g = groupes.findById(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        boolean proprietaire = g.getPorteurId().equals(acteur.id());
        if (!acteur.estAdministrateur() && !proprietaire) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-24",
                    "Seul un administrateur ou le porteur du groupe peut l'annuler");
        }
        if (motif == null || motif.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-68", "Un motif d'annulation est obligatoire");
        }
        if (!g.getStatut().annulable()) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-24",
                    "Un groupe ne peut plus être annulé une fois l'objectif atteint");
        }
        String auteur = (acteur.estAdministrateur() ? "ADMIN" : acteur.type()) + ":" + acteur.id();
        moteur.transitionner(groupeId, StatutGroupe.ANNULE, auteur, motif);
        audit.tracer(acteur.id(), "GROUPE_ANNULE", "groupe=" + groupeId, motif);
        if (!proprietaire) {
            notifications.notifier(g.getPorteurId(), "Votre groupe #" + groupeId + " a été annulé. Motif : " + motif);
        }
        return vue(groupes.findById(groupeId).orElseThrow());
    }

    /** RG-21 / RG-22 : à la date limite, objectif atteint ou échec. Appelée par le planificateur, une transaction par groupe. */
    @Transactional
    public void cloturerSiEchu(long groupeId) {
        GroupeAchat g = groupes.findById(groupeId).orElse(null);
        if (g == null || g.getStatut() != StatutGroupe.OUVERT || g.getDateLimite().isAfter(horloge.instant())) {
            return;
        }
        boolean atteint = g.getQuantiteConfirmee() >= g.getQuantiteCible();
        moteur.transitionner(groupeId, atteint ? StatutGroupe.OBJECTIF_ATTEINT : StatutGroupe.ECHOUE, "SYSTEME", null);
        audit.tracer(null, atteint ? "GROUPE_OBJECTIF_ATTEINT" : "GROUPE_ECHOUE", "groupe=" + groupeId,
                "confirmee=" + g.getQuantiteConfirmee() + "/" + g.getQuantiteCible());
        notifications.notifier(g.getPorteurId(), atteint
                ? "Le groupe #" + groupeId + " a atteint son objectif."
                : "Le groupe #" + groupeId + " n'a pas atteint son objectif à la date limite : les paiements sont remboursés.");
    }

    /**
     * Le grossiste qui porte un groupe achemine la marchandise par ses propres moyens : il signale chaque étape
     * (départ, transit, douane, arrivée…) aux administrateurs, qui mettent à jour le suivi vu par les commerçants.
     */
    @Transactional
    public void signalerEtape(long grossisteId, long groupeId, String etape, String commentaire) {
        GroupeAchat g = groupeDuPorteur(grossisteId, groupeId);
        if (!g.estPorteParGrossiste()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, null, "L'acheminement de ce groupe est géré par son courtier");
        }
        StatutGroupe s = g.getStatut();
        boolean estIncident = etape.contains("âš ï¸") || etape.toLowerCase().contains("incident") || etape.toLowerCase().contains("problème");
        if (!estIncident && s != StatutGroupe.OBJECTIF_ATTEINT && s != StatutGroupe.EN_EXPEDITION && s != StatutGroupe.LIVRE) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, null,
                    "Les étapes d'acheminement se signalent une fois l'objectif atteint (état actuel : " + s + ")");
        }
        String precision = commentaire == null || commentaire.isBlank() ? null : commentaire.strip();
        etapes.save(new EtapeAcheminement(groupeId, etape.strip(), precision, horloge.instant(), grossisteId));
        String detail = etape.strip() + (precision == null ? "" : " — " + precision);
        audit.tracer(grossisteId, estIncident ? "INCIDENT_LOGISTIQUE_GROSSISTE" : "ETAPE_ACHEMINEMENT_SIGNALEE", "groupe=" + groupeId, detail);
        String titre = g.getTitre() != null ? g.getTitre()
                : catalogue.produit(g.getProduitId()).map(CatalogueApi.ProduitInfo::nom).orElse("");
        for (Long admin : identite.administrateursActifs()) {
            String prefixe = estIncident ? "🚨 ALERTE INCIDENT LOGISTIQUE" : "Suivi colis";
            notifications.notifier(admin, prefixe + " — groupe #" + groupeId + " « " + titre + " » : " + detail
                    + ". Mettez à jour le suivi vu par les commerçants.");
        }
    }

    @Transactional
    public void signalerIncident(long grossisteId, long groupeId, String motif, String detail, String pieceJointeUrl) {
        GroupeAchat g = groupes.findById(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        if (!g.getGrossisteId().equals(grossisteId) && (g.getCourtierId() == null || !g.getCourtierId().equals(grossisteId))) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, null, "Vous n'êtes pas associé à ce groupe");
        }
        String titre = g.getTitre() != null ? g.getTitre()
                : catalogue.produit(g.getProduitId()).map(CatalogueApi.ProduitInfo::nom).orElse("");
        String libelle = "âš ï¸ " + motif + (pieceJointeUrl != null && !pieceJointeUrl.isBlank() ? " [PJ: " + pieceJointeUrl + "]" : "");
        String precision = detail == null || detail.isBlank() ? null : detail.strip();
        etapes.save(new EtapeAcheminement(groupeId, libelle, precision, horloge.instant(), grossisteId));
        audit.tracer(grossisteId, "INCIDENT_LOGISTIQUE_GROSSISTE", "groupe=" + groupeId, motif + (precision != null ? " : " + precision : ""));
        for (Long admin : identite.administrateursActifs()) {
            notifications.notifier(admin, "🚨 ALERTE INCIDENT LOGISTIQUE — groupe #" + groupeId + " « " + titre + " » : "
                    + motif + (precision != null ? " — " + precision : "") + ". Intervention recommandée.");
        }
    }

    /** Étapes signalées par le grossiste porteur, de la plus ancienne à la plus récente (lui et les administrateurs). */
    @Transactional(readOnly = true)
    public List<EtapeVue> etapes(UtilisateurCourant demandeur, long groupeId) {
        GroupeAchat g = groupes.findById(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        if (!demandeur.estAdministrateur() && !g.getPorteurId().equals(demandeur.id())) {
            throw ErreurMetier.nonTrouve("Groupe", groupeId);
        }
        return etapes.findByGroupeIdOrderByIdAsc(groupeId).stream()
                .map(e -> new EtapeVue(e.getId(), e.getEtape(), e.getCommentaire(), e.getDateSignalee())).toList();
    }

    // ---------------------------------------------------------------------- consultation

    /** Les groupes que l'acteur pilote : ceux du courtier, ou tous ceux montés sur les produits du grossiste. */
    @Transactional(readOnly = true)
    public List<GroupeVue> mesGroupes(UtilisateurCourant moi) {
        return "GROSSISTE".equals(moi.type()) ? duGrossiste(moi.id()) : duCourtier(moi.id());
    }

    /** Groupes ouverts, avec filtres facultatifs sur la catégorie et le nom du produit (RG-14 : catégories inactives comprises). */
    @Transactional(readOnly = true)
    public List<GroupeVue> explorer(Long categorieId, String recherche) {
        String q = recherche == null ? null : recherche.strip().toLowerCase(Locale.ROOT);
        return groupes.findByStatutOrderByDateLimiteAsc(StatutGroupe.OUVERT).stream()
                .map(this::vue)
                .map(this::anonymiserPourCommercant)
                .filter(v -> categorieId == null || catalogue.produit(v.produit().id())
                        .map(p -> p.categorieId() == categorieId).orElse(false))
                .filter(v -> q == null || q.isEmpty() || v.produit().nom().toLowerCase(Locale.ROOT).contains(q))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<GroupeVue> duCourtier(long courtierId) {
        return groupes.findByCourtierIdOrderByIdDesc(courtierId).stream().map(this::vue).toList();
    }

    @Transactional(readOnly = true)
    public List<GroupeVue> aValiderParGrossiste(long grossisteId) {
        return groupes.findByGrossisteIdAndStatutOrderByIdAsc(grossisteId, StatutGroupe.EN_VALIDATION).stream()
                .map(this::vue).toList();
    }

    /** Tous les groupes montés sur les produits du Grossiste, du plus récent au plus ancien. */
    @Transactional(readOnly = true)
    public List<GroupeVue> duGrossiste(long grossisteId) {
        return groupes.findByGrossisteIdOrderByIdDesc(grossisteId).stream().map(this::vue).toList();
    }

    /** Tous les groupes, du plus récent au plus ancien (supervision administrateur). */
    @Transactional(readOnly = true)
    public List<GroupeVue> tous() {
        return groupes.findAll(org.springframework.data.domain.Sort.by(
                org.springframework.data.domain.Sort.Direction.DESC, "id")).stream().map(this::vue).toList();
    }

    @Transactional(readOnly = true)
    public List<GroupeVue> enValidation() {
        return groupes.findByStatutOrderByDateLimiteAsc(StatutGroupe.EN_VALIDATION).stream().map(this::vue).toList();
    }

    @Transactional(readOnly = true)
    public GroupeVue detail(UtilisateurCourant demandeur, long groupeId) {
        GroupeVue v = vue(visible(demandeur, groupeId));
        if (demandeur != null && "COMMERCANT".equals(demandeur.type())) {
            return anonymiserPourCommercant(v);
        }
        return v;
    }

    private GroupeVue anonymiserPourCommercant(GroupeVue v) {
        return new GroupeVue(v.id(), v.titre(), v.statut(), v.produit(), v.courtier(),
                null, v.porteParGrossiste(), v.quantiteCible(), v.quantiteConfirmee(), v.quantiteReservee(),
                v.quantiteRestante(), v.prixUnitaire(), null, v.conditions(), v.dateOuverture(),
                v.dateLimite(), v.disponibiliteValidee(), v.paysOrigineCode(), v.paysOrigineNom());
    }

    @Transactional(readOnly = true)
    public List<TransitionVue> historique(UtilisateurCourant demandeur, long groupeId) {
        visible(demandeur, groupeId);
        return transitions.findByGroupeIdOrderByIdAsc(groupeId).stream()
                .map(t -> new TransitionVue(t.getAncienStatut().name(), t.getNouveauStatut().name(),
                        t.getDateTransition(), t.getAuteur())).toList();
    }

    // ------------------------------------------------------------------------ utilitaires

    /** Brouillons et groupes en validation : visibles seulement de leur courtier, de leur grossiste et des administrateurs. */
    private GroupeAchat visible(UtilisateurCourant u, long groupeId) {
        GroupeAchat g = groupes.findById(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        boolean admin = u.estAdministrateur();
        boolean courtier = g.getCourtierId() != null && g.getCourtierId().equals(u.id());
        boolean grossiste = g.getGrossisteId().equals(u.id());
        if ("GROSSISTE".equals(u.type()) && !grossiste) {
            throw ErreurMetier.nonTrouve("Groupe", groupeId);
        }
        boolean prive = g.getStatut() == StatutGroupe.BROUILLON || g.getStatut() == StatutGroupe.EN_VALIDATION;
        if (prive && !(admin || courtier || grossiste)) {
            throw ErreurMetier.nonTrouve("Groupe", groupeId);
        }
        return g;
    }

    private GroupeAchat groupeDuPorteur(long porteurId, long groupeId) {
        return groupes.findById(groupeId).filter(g -> g.getPorteurId().equals(porteurId))
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
    }

    private static String titre(Demande d) {
        if (d.titre() == null || d.titre().isBlank()) {
            return null;
        }
        String t = d.titre().strip();
        if (t.length() > 120) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-17", "Le titre du groupe dépasse 120 caractères");
        }
        return t;
    }

    private record Calcul(int quantiteCible, CalculPrix.Composantes composantes, BigDecimal prixUnitaire, int delai,
                          int minimum) {
    }

    private Calcul calculer(Demande d, Instant maintenant) {
        if (d.quantiteCible() == null || d.quantiteCible() <= 0) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-17", "La quantité cible doit être positive");
        }
        if (d.dateLimite() == null || !d.dateLimite().isAfter(maintenant)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-17",
                    "La date limite doit être postérieure à la date d'ouverture");
        }
        int minimum = d.quantiteMinParCommercant() == null ? 1 : d.quantiteMinParCommercant();
        if (minimum < 1 || minimum > d.quantiteCible()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-27",
                    "Le minimum par commerçant doit être compris entre 1 et la quantité cible");
        }
        int delai = d.delaiLivraisonJours() == null ? 0 : d.delaiLivraisonJours();
        if (delai < 0) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-17", "Le délai de livraison est invalide");
        }
        if (d.marchandise() == null) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-17", "Le prix de la marchandise est obligatoire");
        }
        // RG-37 : les frais de plateforme sont calculés par DoGo, jamais saisis.
        BigDecimal frais = CalculPrix.fraisPlateforme(d.marchandise(), proprietes.commission().taux());
        CalculPrix.Composantes c = new CalculPrix.Composantes(d.marchandise(), d.transport(), frais, d.douane(),
                d.autres());
        return new Calcul(d.quantiteCible(), c, CalculPrix.totalUnitaire(c), delai, minimum);
    }

        @Transactional
    public GroupeVue assignerPaysOrigine(long adminId, long groupeId, String paysCode) {
        if (paysCode == null || paysCode.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-PAYS", "Le pays d'origine est obligatoire");
        }
        Pays pays = paysService.resoudre(paysCode)
                .filter(Pays::isActif)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-PAYS",
                        "Pays d'origine non reconnu ou inactif : " + paysCode));
        String code = pays.getCodeIso();
        GroupeAchat g = groupes.findById(groupeId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        g.assignerPaysOrigine(code);
        groupes.save(g);
        audit.tracer(adminId, "GROUPE_PAYS_ASSIGNE", "groupe=" + groupeId, "pays=" + code);
        return vue(g);
    }

    GroupeVue vue(GroupeAchat g) {
        CatalogueApi.ProduitInfo p = catalogue.produit(g.getProduitId()).orElseThrow();
        GrilleTarifaire grille = grilles.findByGroupeId(g.getId()).orElseThrow();
        ConditionCommerciale cond = conditions.findByGroupeId(g.getId()).orElseThrow();
        String codePays = g.getPaysOrigineCode();
        String nomPays = null;
        if (codePays == null && p.paysOrigine() != null && !p.paysOrigine().isBlank()) {
            java.util.Optional<Pays> pOpt = paysService.resoudre(p.paysOrigine());
            if (pOpt.isPresent()) {
                codePays = pOpt.get().getCodeIso();
                nomPays = pOpt.get().getNomFr();
                try {
                    g.assignerPaysOrigine(codePays);
                    groupes.save(g);
                } catch (Exception ignored) {
                }
            }
        }
        if (codePays != null && nomPays == null) {
            nomPays = paysService.resoudre(codePays).map(Pays::getNomFr).orElse(codePays);
        }
        return new GroupeVue(g.getId(), g.getTitre() != null ? g.getTitre() : p.nom(), g.getStatut().name(),
                new ProduitVue(p.id(), p.nom(), p.description(), p.paysOrigine(), p.categorie(), p.photoUrl(),
                        p.variantes().stream().map(v -> new VarianteVue(v.id(), v.sku(), v.taille(), v.couleur())).toList()),
                g.getCourtierId() == null ? null : acteur(g.getCourtierId()), acteur(g.getGrossisteId()),
                g.estPorteParGrossiste(), g.getQuantiteCible(), g.getQuantiteConfirmee(),
                g.getQuantiteReservee(),
                Math.max(0, g.getQuantiteCible() - g.getQuantiteConfirmee() - g.getQuantiteReservee()),
                g.getPrixUnitaire(),
                new GrilleVue(grille.getPrixMarchandise(), grille.getTransport(), grille.getFraisPlateforme(),
                        grille.getDouane(), grille.getAutres(), grille.getDevise()),
                new ConditionsVue(cond.getDelaiLivraisonJours(), cond.getPolitiqueAnnulation(),
                        cond.getQuantiteMinParCommercant()),
                g.getDateOuverture(), g.getDateLimite(), g.isDisponibiliteValidee(),
                codePays, nomPays);
    }

    private ActeurVue acteur(long id) {
        return new ActeurVue(id, identite.acteur(id).map(IdentiteApi.ActeurInfo::nom).orElse("?"));
    }

    // ---------------------------------------------------------------- planificateur

    /** Clôture des groupes échus, chacun dans sa propre transaction (appel via le proxy Spring). */
    @Component
    public static class Planificateur {

        private static final org.slf4j.Logger LOG = org.slf4j.LoggerFactory.getLogger(Planificateur.class);

        private final GroupeAchatRepository groupes;
        private final GroupeService service;
        private final Clock horloge;

        public Planificateur(GroupeAchatRepository groupes, GroupeService service, Clock horloge) {
            this.groupes = groupes;
            this.service = service;
            this.horloge = horloge;
        }

        @Scheduled(fixedDelay = 60_000, initialDelay = 30_000)
        public void cloturerLesGroupesEchus() {
            for (Long id : groupes.identifiantsOuvertsEchus(horloge.instant())) {
                try {
                    service.cloturerSiEchu(id);
                } catch (RuntimeException e) {
                    LOG.error("Clôture du groupe {} impossible", id, e);
                }
            }
        }
    }
}

