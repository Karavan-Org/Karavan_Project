package ml.dogo.groupeachat.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import ml.dogo.catalogue.api.CatalogueApi;
import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.groupeachat.persistence.ConditionCommercialeRepository;
import ml.dogo.groupeachat.persistence.EtapeAcheminementRepository;
import ml.dogo.groupeachat.persistence.GrilleTarifaireRepository;
import ml.dogo.groupeachat.persistence.GroupeAchat;
import ml.dogo.groupeachat.persistence.GroupeAchatRepository;
import ml.dogo.groupeachat.persistence.Pays;
import ml.dogo.groupeachat.persistence.PaysRepository;
import ml.dogo.identite.api.IdentiteApi;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class TableauDeBordAdminServiceTest {

    private final GroupeAchatRepository groupes = mock(GroupeAchatRepository.class);
    private final PaysRepository paysRepository = mock(PaysRepository.class);
    private final EtapeAcheminementRepository etapes = mock(EtapeAcheminementRepository.class);
    private final GrilleTarifaireRepository grilles = mock(GrilleTarifaireRepository.class);
    private final ConditionCommercialeRepository conditions = mock(ConditionCommercialeRepository.class);
    private final CatalogueApi catalogue = mock(CatalogueApi.class);
    private final IdentiteApi identite = mock(IdentiteApi.class);
    private final GroupeService groupeService = mock(GroupeService.class);
    private final Clock horloge = Clock.fixed(Instant.parse("2026-10-28T12:00:00Z"), ZoneId.of("UTC"));

    private TableauDeBordAdminService service;

    @BeforeEach
    void setUp() {
        service = new TableauDeBordAdminService(
                groupes, paysRepository, etapes, grilles, conditions, catalogue, identite, groupeService, horloge);
    }

    @Test
    void resumeCalculeAgregationsExactesEtGroupesSansPays() {
        // Mock Utilisateurs
        when(identite.statistiquesSupervision()).thenReturn(new IdentiteApi.SupervisionStats(150, 12, 5, 2));

        // Mock Groupes par statut
        List<Object[]> statutsCounts = List.of(
                new Object[]{StatutGroupe.OUVERT, 4L},
                new Object[]{StatutGroupe.OBJECTIF_ATTEINT, 2L},
                new Object[]{StatutGroupe.EN_EXPEDITION, 1L}
        );
        when(groupes.compterParStatut()).thenReturn(statutsCounts);

        // Mock Répartition par pays
        List<Object[]> paysCounts = List.of(
                new Object[]{"CN", 5L},
                new Object[]{"TR", 2L}
        );
        when(groupes.compterParPaysOrigine()).thenReturn(paysCounts);

        // Mock Pays table
        Pays chine = new Pays("CN", "CHN", "Chine", 35.8617, 104.1954, true);
        Pays turquie = new Pays("TR", "TUR", "Turquie", 38.9637, 35.2433, true);
        when(paysRepository.findAll()).thenReturn(List.of(chine, turquie));

        // Mock Groupes sans pays
        when(groupes.compterGroupesSansPays()).thenReturn(3L);

        // Mock Lancés ce mois
        when(groupes.compterLancesApres(any())).thenReturn(6L);

        TableauDeBordAdminService.ResumeVue res = service.resume();

        assertNotNull(res);
        assertEquals(150, res.utilisateurs().clients());
        assertEquals(12, res.utilisateurs().grossistes());
        assertEquals(5, res.utilisateurs().courtiers());
        assertEquals(167, res.utilisateurs().total());

        assertEquals(7, res.totalGroupes());
        assertEquals(4L, res.groupesParStatut().get("OUVERT"));
        assertEquals(2L, res.groupesParStatut().get("OBJECTIF_ATTEINT"));

        // Répartition pays
        assertEquals(2, res.repartitionPays().size());
        assertEquals("CN", res.repartitionPays().get(0).codeIso());
        assertEquals(5L, res.repartitionPays().get(0).nombreGroupes());
        assertEquals(71.4, res.repartitionPays().get(0).pourcentage()); // 5 / 7 = 71.4%

        // Groupes sans pays
        assertEquals(3L, res.groupesSansPays());
        assertEquals(6L, res.groupesLancesMois());
    }

    @Test
    void groupesPourCadranConstruitObjetsLegersAvecProgression() {
        GroupeAchat g = new GroupeAchat(
                10L, 20L, 30L, "Campagne Textiles Istanbul", "TR", 500, BigDecimal.valueOf(15000),
                Instant.parse("2026-10-01T10:00:00Z"), Instant.parse("2026-11-01T10:00:00Z"));
        org.springframework.test.util.ReflectionTestUtils.setField(g, "id", 100L);

        when(groupes.rechercherPourCadran(any(), any(), any(), any())).thenReturn(List.of(g));
        when(paysRepository.findAll()).thenReturn(List.of(new Pays("TR", "TUR", "Turquie", 38.9637, 35.2433, true)));
        when(identite.acteur(20L)).thenReturn(Optional.of(new IdentiteApi.ActeurInfo(20L, "GROSSISTE", "ACTIF", "Modibo Grossiste", "+22370000020")));
        when(identite.acteur(10L)).thenReturn(Optional.of(new IdentiteApi.ActeurInfo(10L, "COURTIER", "ACTIF", "Oumar Courtier", "+22370000010")));
        when(catalogue.produit(30L)).thenReturn(Optional.of(new CatalogueApi.ProduitInfo(30L, 20L, 1L, "Vêtements", "Robes", "desc", "Turquie", null, List.of())));
        when(etapes.findByGroupeIdOrderByIdAsc(any())).thenReturn(List.of());

        List<TableauDeBordAdminService.GroupeCadranVue> liste = service.groupesPourCadran(null, null, null, 0, 50);

        assertNotNull(liste);
        assertEquals(1, liste.size());
        TableauDeBordAdminService.GroupeCadranVue cadran = liste.get(0);
        assertEquals("Campagne Textiles Istanbul", cadran.titre());
        assertEquals("TR", cadran.paysOrigine().codeIso());
        assertEquals("Turquie", cadran.paysOrigine().nomFr());
        assertEquals("Modibo Grossiste", cadran.grossiste().nom());
        assertEquals("Oumar Courtier", cadran.courtier().nom());
        assertEquals("Vêtements", cadran.categorieNom());
    }
}
