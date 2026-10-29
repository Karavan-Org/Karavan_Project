package ml.dogo.groupeachat.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import ml.dogo.catalogue.api.CatalogueApi;
import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.groupeachat.persistence.ConditionCommerciale;
import ml.dogo.groupeachat.persistence.ConditionCommercialeRepository;
import ml.dogo.groupeachat.persistence.EtapeAcheminement;
import ml.dogo.groupeachat.persistence.EtapeAcheminementRepository;
import ml.dogo.groupeachat.persistence.GrilleTarifaire;
import ml.dogo.groupeachat.persistence.GrilleTarifaireRepository;
import ml.dogo.groupeachat.persistence.GroupeAchat;
import ml.dogo.groupeachat.persistence.GroupeAchatRepository;
import ml.dogo.groupeachat.persistence.Pays;
import ml.dogo.groupeachat.persistence.PaysRepository;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service dédié au nouveau Tableau de Bord Administrateur Karavan :
 * agrégations pour le Globe 3D terrestre et le Cadran rotatif des groupes.
 */
@Service
@Transactional(readOnly = true)
public class TableauDeBordAdminService {

    public record PaysVue(String codeIso, String codeIso3, String nomFr, Double latitude, Double longitude) {
        public static PaysVue de(Pays p) {
            return new PaysVue(p.getCodeIso(), p.getCodeIso3(), p.getNomFr(), p.getLatitude(), p.getLongitude());
        }
    }

    public record RepartitionPaysVue(String codeIso, String nomFr, long nombreGroupes, double pourcentage,
                                     Double latitude, Double longitude) {
    }

    public record UtilisateursResume(long clients, long grossistes, long courtiers, long total) {
    }

    public record ActiviteRecenteVue(
            String type,
            Long id,
            String titre,
            String sousTitre,
            String paysCode,
            String paysNom,
            String drapeau,
            Instant date
    ) {
    }

    public record ResumeVue(
            UtilisateursResume utilisateurs,
            long totalGroupes,
            Map<String, Long> groupesParStatut,
            List<RepartitionPaysVue> repartitionPays,
            long groupesSansPays,
            long groupesLancesMois,
            double progressionMoyenne,
            long groupesComplets,
            long retardsSuivi,
            List<ActiviteRecenteVue> activiteRecente
    ) {
    }

    public record ActeurVue(long id, String nom) {
    }

    public record GroupeCadranVue(
            long id,
            String titre,
            String statut,
            PaysVue paysOrigine,
            String drapeau,
            int quantiteCible,
            int quantiteConfirmee,
            int quantiteReservee,
            double progressionPourcentage,
            BigDecimal prixUnitaire,
            Instant dateLancement,
            Instant dateLimite,
            ActeurVue grossiste,
            ActeurVue courtier,
            String etapeSuivi,
            String categorieNom,
            String produitPhotoUrl
    ) {
    }

    public record EtapeVue(long id, String etape, String commentaire, Instant date) {
    }

    public record GroupeDetailVue(
            long id,
            String titre,
            String statut,
            PaysVue paysOrigine,
            int quantiteCible,
            int quantiteConfirmee,
            int quantiteReservee,
            int quantiteRestante,
            double progressionPourcentage,
            BigDecimal prixUnitaire,
            Instant dateLancement,
            Instant dateLimite,
            boolean disponibiliteValidee,
            boolean porteParGrossiste,
            ActeurVue grossiste,
            ActeurVue courtier,
            String produitNom,
            String produitDescription,
            String produitPhotoUrl,
            String categorieNom,
            BigDecimal prixMarchandise,
            BigDecimal transport,
            BigDecimal fraisPlateforme,
            BigDecimal douane,
            BigDecimal autres,
            String devise,
            int delaiLivraisonJours,
            String politiqueAnnulation,
            int quantiteMinParCommercant,
            List<EtapeVue> etapesAcheminement
    ) {
    }

    private static final long DUREE_CACHE_MS = 30_000L; // Cache court de 30 secondes pour le résumé
    private record CacheEntree(ResumeVue vue, long timestamp) {}
    private volatile CacheEntree cacheResume = null;

    private final GroupeAchatRepository groupes;
    private final PaysRepository paysRepository;
    private final EtapeAcheminementRepository etapes;
    private final GrilleTarifaireRepository grilles;
    private final ConditionCommercialeRepository conditions;
    private final CatalogueApi catalogue;
    private final IdentiteApi identite;
    private final GroupeService groupeService;
    private final Clock horloge;
    private final org.springframework.jdbc.core.JdbcTemplate jdbc;
    private final PaysService paysService;

    @org.springframework.beans.factory.annotation.Autowired
    public TableauDeBordAdminService(GroupeAchatRepository groupes,
                                     PaysRepository paysRepository,
                                     EtapeAcheminementRepository etapes,
                                     GrilleTarifaireRepository grilles,
                                     ConditionCommercialeRepository conditions,
                                     CatalogueApi catalogue,
                                     IdentiteApi identite,
                                     GroupeService groupeService,
                                     Clock horloge,
                                     org.springframework.jdbc.core.JdbcTemplate jdbc,
                                     PaysService paysService) {
        this.groupes = groupes;
        this.paysRepository = paysRepository;
        this.etapes = etapes;
        this.grilles = grilles;
        this.conditions = conditions;
        this.catalogue = catalogue;
        this.identite = identite;
        this.groupeService = groupeService;
        this.horloge = horloge;
        this.jdbc = jdbc;
        this.paysService = paysService != null ? paysService : new PaysService(paysRepository);
    }

    public TableauDeBordAdminService(GroupeAchatRepository groupes,
                                     PaysRepository paysRepository,
                                     EtapeAcheminementRepository etapes,
                                     GrilleTarifaireRepository grilles,
                                     ConditionCommercialeRepository conditions,
                                     CatalogueApi catalogue,
                                     IdentiteApi identite,
                                     GroupeService groupeService,
                                     Clock horloge,
                                     org.springframework.jdbc.core.JdbcTemplate jdbc) {
        this(groupes, paysRepository, etapes, grilles, conditions, catalogue, identite, groupeService, horloge, jdbc,
                new PaysService(paysRepository));
    }

    /**
     * Résumé analytique pour les compteurs et la colonne droite de statistiques.
     * Met en cache le résultat pendant 30 s pour soulager la base de données.
     */
    public ResumeVue resume() {
        CacheEntree c = cacheResume;
        long maintenantMs = System.currentTimeMillis();
        if (c != null && maintenantMs - c.timestamp < DUREE_CACHE_MS) {
            return c.vue;
        }

        // 1. Utilisateurs
        IdentiteApi.SupervisionStats uStats = identite.statistiquesSupervision();
        UtilisateursResume uResume = new UtilisateursResume(
                uStats.commercants(),
                uStats.grossistes(),
                uStats.courtiers(),
                uStats.totalActeurs()
        );

        // 2. Groupes par statut
        Map<String, Long> groupesParStatut = new HashMap<>();
        for (StatutGroupe s : StatutGroupe.values()) {
            groupesParStatut.put(s.name(), 0L);
        }
        long totalGroupes = 0;
        List<Object[]> statutsLignes = groupes.compterParStatut();
        for (Object[] ligne : statutsLignes) {
            if (ligne != null && ligne.length >= 2 && ligne[0] != null) {
                String statut = ((StatutGroupe) ligne[0]).name();
                long count = ((Number) ligne[1]).longValue();
                groupesParStatut.put(statut, count);
                totalGroupes += count;
            }
        }

        // 3. Répartition par pays d'origine
        // Auto-assignation pour les groupes qui n'avaient pas encore leur pays renseigné en base
        try {
            List<GroupeAchat> tousGroupes = groupes.findAll();
            boolean modifie = false;
            for (GroupeAchat g : tousGroupes) {
                if (g.getPaysOrigineCode() == null) {
                    Optional<CatalogueApi.ProduitInfo> prod = catalogue.produit(g.getProduitId());
                    if (prod.isPresent() && prod.get().paysOrigine() != null && !prod.get().paysOrigine().isBlank()) {
                        Optional<Pays> pOpt = paysService.resoudre(prod.get().paysOrigine());
                        if (pOpt.isPresent()) {
                            g.assignerPaysOrigine(pOpt.get().getCodeIso());
                            groupes.save(g);
                            modifie = true;
                        }
                    }
                }
            }
            if (modifie) {
                groupes.flush();
            }
        } catch (Exception ignored) {
        }

        List<Object[]> paysLignes = groupes.compterParPaysOrigine();
        long totalAvecPays = 0;
        Map<String, Long> comptesParCode = new HashMap<>();
        for (Object[] ligne : paysLignes) {
            if (ligne != null && ligne.length >= 2 && ligne[0] != null) {
                String code = ((String) ligne[0]).toUpperCase();
                long count = ((Number) ligne[1]).longValue();
                comptesParCode.put(code, count);
                totalAvecPays += count;
            }
        }

        List<RepartitionPaysVue> repartitionPays = new ArrayList<>();
        Map<String, Pays> tousPays = new HashMap<>();
        paysRepository.findAll().forEach(p -> tousPays.put(p.getCodeIso().toUpperCase(), p));

        for (Map.Entry<String, Long> e : comptesParCode.entrySet()) {
            String code = e.getKey();
            long count = e.getValue();
            double pourcentage = totalAvecPays > 0 ? (count * 100.0) / totalAvecPays : 0.0;
            BigDecimal bd = BigDecimal.valueOf(pourcentage).setScale(1, RoundingMode.HALF_UP);
            Pays p = tousPays.get(code);
            String nom = p != null ? p.getNomFr() : code;
            Double lat = p != null ? p.getLatitude() : null;
            Double lon = p != null ? p.getLongitude() : null;
            repartitionPays.add(new RepartitionPaysVue(code, nom, count, bd.doubleValue(), lat, lon));
        }
        repartitionPays.sort((a, b) -> Long.compare(b.nombreGroupes(), a.nombreGroupes()));

        // 4. Groupes sans pays
        long groupesSansPays = groupes.compterGroupesSansPays();

        // 5. Groupes lancés ce mois-ci
        LocalDate premierDuMois = LocalDate.now(horloge).withDayOfMonth(1);
        Instant debutMois = premierDuMois.atStartOfDay(ZoneId.systemDefault()).toInstant();
        long groupesLancesMois = groupes.compterLancesApres(debutMois);

        // 6. Progression moyenne des groupes actifs
        List<GroupeAchat> tousActifs = groupes.findAll();
        double progressionMoyenne = 0.0;
        long complets = 0;
        long nbActifs = 0;
        for (GroupeAchat g : tousActifs) {
            if (g.getStatut() == StatutGroupe.OUVERT || g.getStatut() == StatutGroupe.OBJECTIF_ATTEINT
                    || g.getStatut() == StatutGroupe.EN_EXPEDITION || g.getStatut() == StatutGroupe.LIVRE) {
                nbActifs++;
                double prog = g.getQuantiteCible() > 0
                        ? (g.getQuantiteConfirmee() * 100.0) / g.getQuantiteCible()
                        : 0.0;
                progressionMoyenne += prog;
            }
            if (g.getStatut() == StatutGroupe.OBJECTIF_ATTEINT || g.getStatut() == StatutGroupe.TERMINE
                    || g.getStatut() == StatutGroupe.LIVRE) {
                complets++;
            }
        }
        if (nbActifs > 0) {
            progressionMoyenne = BigDecimal.valueOf(progressionMoyenne / nbActifs)
                    .setScale(1, RoundingMode.HALF_UP).doubleValue();
        }

        // 7. Retards de suivi
        long retardsSuivi = 0;

        // 8. Activité récente en temps réel
        List<ActiviteRecenteVue> activite = new ArrayList<>();
        Map<String, Pays> paysMap = new HashMap<>();
        paysRepository.findAll().forEach(p -> paysMap.put(p.getCodeIso().toUpperCase(), p));

        // Groupes récents
        org.springframework.data.domain.Page<GroupeAchat> pageRecents = groupes.findAll(
                PageRequest.of(0, 6, org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "id"))
        );
        List<GroupeAchat> recentsGroupes = pageRecents != null ? pageRecents.getContent() : Collections.emptyList();
        for (GroupeAchat g : recentsGroupes) {
            String pCode = g.getPaysOrigineCode();
            String pNom = "Mali";
            String drapeau = "🇲🇱";
            if (pCode != null && paysMap.containsKey(pCode.toUpperCase())) {
                Pays p = paysMap.get(pCode.toUpperCase());
                pNom = p.getNomFr();
                drapeau = obtenirDrapeau(p.getCodeIso());
            }
            String grossisteNom = identite.acteur(g.getGrossisteId()).map(IdentiteApi.ActeurInfo::nom).orElse("Grossiste #" + g.getGrossisteId());
            activite.add(new ActiviteRecenteVue(
                    "GROUPE",
                    g.getId(),
                    "Groupe #" + g.getId(),
                    "Grossiste : " + grossisteNom + " • " + pNom,
                    pCode != null ? pCode : "ML",
                    pNom,
                    drapeau,
                    g.getDateOuverture()
            ));
        }

        // Utilisateurs récents
        try {
            jdbc.query(
                "SELECT id, nom, date_creation, type_acteur FROM utilisateur ORDER BY date_creation DESC LIMIT 4",
                rs -> {
                    long uid = rs.getLong("id");
                    String uNom = rs.getString("nom");
                    java.sql.Timestamp ts = rs.getTimestamp("date_creation");
                    Instant uDate = ts != null ? ts.toInstant() : horloge.instant();
                    activite.add(new ActiviteRecenteVue(
                            "UTILISATEUR",
                            uid,
                            "Nouvel utilisateur",
                            uNom != null ? uNom : "Utilisateur #" + uid,
                            "ML",
                            "Mali",
                            "🇲🇱",
                            uDate
                    ));
                }
            );
        } catch (Exception ignored) {
        }
        activite.sort((a, b) -> b.date().compareTo(a.date()));

        ResumeVue vue = new ResumeVue(
                uResume,
                totalGroupes,
                groupesParStatut,
                repartitionPays,
                groupesSansPays,
                groupesLancesMois,
                progressionMoyenne,
                complets,
                retardsSuivi,
                activite
        );

        cacheResume = new CacheEntree(vue, maintenantMs);
        return vue;
    }

    public static String obtenirDrapeau(String codeIso) {
        if (codeIso == null || codeIso.length() != 2) return "🌍";
        String code = codeIso.toUpperCase();
        int premier = 0x1F1E6 + (code.charAt(0) - 'A');
        int second = 0x1F1E6 + (code.charAt(1) - 'A');
        return new String(Character.toChars(premier)) + new String(Character.toChars(second));
    }

    /**
     * Liste légère des groupes pour l'affichage interactif sur le cadran rotatif.
     */
    public List<GroupeCadranVue> groupesPourCadran(StatutGroupe statut, String paysCode, String recherche,
                                                   int page, int taille) {
        int limiteTaille = Math.min(Math.max(1, taille), 200);
        int pageIndex = Math.max(0, page);
        String paysFiltre = (paysCode != null && !paysCode.isBlank()) ? paysCode.trim().toUpperCase() : null;
        String rechercheFiltre = (recherche != null && !recherche.isBlank()) ? recherche.trim() : null;

        List<GroupeAchat> liste = groupes.rechercherPourCadran(
                statut,
                paysFiltre,
                rechercheFiltre,
                PageRequest.of(pageIndex, limiteTaille)
        );

        Map<String, Pays> paysCache = new HashMap<>();
        paysRepository.findAll().forEach(p -> paysCache.put(p.getCodeIso().toUpperCase(), p));

        List<GroupeCadranVue> resultats = new ArrayList<>();
        for (GroupeAchat g : liste) {
            PaysVue pVue = null;
            if (g.getPaysOrigineCode() != null) {
                pVue = paysService.resoudre(g.getPaysOrigineCode()).map(PaysVue::de).orElse(null);
            }

            double progression = g.getQuantiteCible() > 0
                    ? BigDecimal.valueOf((g.getQuantiteConfirmee() * 100.0) / g.getQuantiteCible())
                        .setScale(1, RoundingMode.HALF_UP).doubleValue()
                    : 0.0;

            String grossisteNom = identite.acteur(g.getGrossisteId()).map(IdentiteApi.ActeurInfo::nom).orElse("Grossiste #" + g.getGrossisteId());
            ActeurVue grossisteVue = new ActeurVue(g.getGrossisteId(), grossisteNom);

            ActeurVue courtierVue = null;
            if (g.getCourtierId() != null) {
                String courtierNom = identite.acteur(g.getCourtierId()).map(IdentiteApi.ActeurInfo::nom).orElse("Courtier #" + g.getCourtierId());
                courtierVue = new ActeurVue(g.getCourtierId(), courtierNom);
            }

            List<EtapeAcheminement> etapesListe = etapes.findByGroupeIdOrderByIdAsc(g.getId());
            String derniereEtape = etapesListe.isEmpty() ? "En attente" : etapesListe.get(etapesListe.size() - 1).getEtape();

            String categorieNom = catalogue.produit(g.getProduitId())
                    .map(CatalogueApi.ProduitInfo::categorie)
                    .orElse("Général");

            String titre = g.getTitre();
            if (titre == null || titre.isBlank()) {
                titre = catalogue.produit(g.getProduitId()).map(CatalogueApi.ProduitInfo::nom).orElse("Groupe #" + g.getId());
            }

            String photoUrl = null;
            Optional<CatalogueApi.ProduitInfo> prodInfo = catalogue.produit(g.getProduitId());
            if (prodInfo.isPresent()) {
                photoUrl = prodInfo.get().photoUrl();
                if (pVue == null && prodInfo.get().paysOrigine() != null) {
                    pVue = paysService.resoudre(prodInfo.get().paysOrigine()).map(PaysVue::de).orElse(null);
                }
            }

            String drapeau = (pVue != null) ? obtenirDrapeau(pVue.codeIso()) : "🌍";

            resultats.add(new GroupeCadranVue(
                    g.getId(),
                    titre,
                    g.getStatut().name(),
                    pVue,
                    drapeau,
                    g.getQuantiteCible(),
                    g.getQuantiteConfirmee(),
                    g.getQuantiteReservee(),
                    progression,
                    g.getPrixUnitaire(),
                    g.getDateOuverture(),
                    g.getDateLimite(),
                    grossisteVue,
                    courtierVue,
                    derniereEtape,
                    categorieNom,
                    photoUrl
            ));
        }

        return resultats;
    }

    /**
     * Détail complet d'un groupe pour le panneau coulissant gauche lors de la sélection sur le cadran ou le globe.
     */
    public GroupeDetailVue detailGroupe(long groupeId) {
        GroupeAchat g = groupes.findById(groupeId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));

        CatalogueApi.ProduitInfo p = catalogue.produit(g.getProduitId())
                .orElseThrow(() -> ErreurMetier.nonTrouve("Produit", g.getProduitId()));
        GrilleTarifaire grille = grilles.findByGroupeId(g.getId()).orElseThrow();
        ConditionCommerciale cond = conditions.findByGroupeId(g.getId()).orElseThrow();

        PaysVue pVue = null;
        if (g.getPaysOrigineCode() != null) {
            pVue = paysService.resoudre(g.getPaysOrigineCode()).map(PaysVue::de).orElse(null);
        } else if (p.paysOrigine() != null) {
            pVue = paysService.resoudre(p.paysOrigine()).map(PaysVue::de).orElse(null);
        }

        double progression = g.getQuantiteCible() > 0
                ? BigDecimal.valueOf((g.getQuantiteConfirmee() * 100.0) / g.getQuantiteCible())
                    .setScale(1, RoundingMode.HALF_UP).doubleValue()
                : 0.0;

        String grossisteNom = identite.acteur(g.getGrossisteId()).map(IdentiteApi.ActeurInfo::nom).orElse("Grossiste #" + g.getGrossisteId());
        ActeurVue grossisteVue = new ActeurVue(g.getGrossisteId(), grossisteNom);

        ActeurVue courtierVue = null;
        if (g.getCourtierId() != null) {
            String courtierNom = identite.acteur(g.getCourtierId()).map(IdentiteApi.ActeurInfo::nom).orElse("Courtier #" + g.getCourtierId());
            courtierVue = new ActeurVue(g.getCourtierId(), courtierNom);
        }

        List<EtapeVue> etapesVues = etapes.findByGroupeIdOrderByIdAsc(g.getId()).stream()
                .map(e -> new EtapeVue(e.getId(), e.getEtape(), e.getCommentaire(), e.getDateSignalee()))
                .toList();

        int restante = Math.max(0, g.getQuantiteCible() - g.getQuantiteConfirmee() - g.getQuantiteReservee());

        String titre = g.getTitre();
        if (titre == null || titre.isBlank()) {
            titre = p.nom();
        }

        return new GroupeDetailVue(
                g.getId(),
                titre,
                g.getStatut().name(),
                pVue,
                g.getQuantiteCible(),
                g.getQuantiteConfirmee(),
                g.getQuantiteReservee(),
                restante,
                progression,
                g.getPrixUnitaire(),
                g.getDateOuverture(),
                g.getDateLimite(),
                g.isDisponibiliteValidee(),
                g.estPorteParGrossiste(),
                grossisteVue,
                courtierVue,
                p.nom(),
                p.description(),
                p.photoUrl(),
                p.categorie(),
                grille.getPrixMarchandise(),
                grille.getTransport(),
                grille.getFraisPlateforme(),
                grille.getDouane(),
                grille.getAutres(),
                grille.getDevise(),
                cond.getDelaiLivraisonJours(),
                cond.getPolitiqueAnnulation(),
                cond.getQuantiteMinParCommercant(),
                etapesVues
        );
    }

    /**
     * Permet à l'administrateur d'assigner ou corriger le pays d'origine d'un groupe en 1 clic.
     */
    @Transactional
    public GroupeService.GroupeVue assignerPays(long adminId, long groupeId, String paysCode) {
        cacheResume = null; // Invalider le cache
        return groupeService.assignerPaysOrigine(adminId, groupeId, paysCode);
    }
}

