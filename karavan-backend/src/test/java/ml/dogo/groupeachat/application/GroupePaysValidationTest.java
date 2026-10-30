package ml.dogo.groupeachat.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.catalogue.api.CatalogueApi;
import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.groupeachat.persistence.ConditionCommercialeRepository;
import ml.dogo.groupeachat.persistence.EtapeAcheminementRepository;
import ml.dogo.groupeachat.persistence.GrilleTarifaireRepository;
import ml.dogo.groupeachat.persistence.GroupeAchat;
import ml.dogo.groupeachat.persistence.GroupeAchatRepository;
import ml.dogo.groupeachat.persistence.Pays;
import ml.dogo.groupeachat.persistence.PaysRepository;
import ml.dogo.groupeachat.persistence.TransitionStatutGroupeRepository;
import ml.dogo.groupeachat.persistence.ValidationGroupeRepository;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class GroupePaysValidationTest {

    private final GroupeAchatRepository groupes = mock(GroupeAchatRepository.class);
    private final GrilleTarifaireRepository grilles = mock(GrilleTarifaireRepository.class);
    private final ConditionCommercialeRepository conditions = mock(ConditionCommercialeRepository.class);
    private final TransitionStatutGroupeRepository transitions = mock(TransitionStatutGroupeRepository.class);
    private final ValidationGroupeRepository validations = mock(ValidationGroupeRepository.class);
    private final MoteurEtatsGroupe moteur = mock(MoteurEtatsGroupe.class);
    private final CatalogueApi catalogue = mock(CatalogueApi.class);
    private final IdentiteApi identite = mock(IdentiteApi.class);
    private final AuditApi audit = mock(AuditApi.class);
    private final NotificationApi notifications = mock(NotificationApi.class);
    private final DogoProperties proprietes = mock(DogoProperties.class, org.mockito.Mockito.RETURNS_DEEP_STUBS);
    private final Clock horloge = Clock.fixed(Instant.parse("2026-10-28T12:00:00Z"), ZoneId.of("UTC"));
    private final EtapeAcheminementRepository etapes = mock(EtapeAcheminementRepository.class);
    private final PaysRepository paysRepository = mock(PaysRepository.class);

    private GroupeService groupeService;

    @BeforeEach
    void setUp() {
        groupeService = new GroupeService(
                groupes, grilles, conditions, transitions, validations, moteur, catalogue,
                identite, audit, notifications, proprietes, horloge, etapes, paysRepository);
    }

    @Test
    void creationRefuseeSiPaysOrigineAbsent() {
        when(identite.exigerActif(10L)).thenReturn(new IdentiteApi.ActeurInfo(10L, "GROSSISTE", "ACTIF", "Grossiste", "+22370000010"));
        when(catalogue.produit(1L)).thenReturn(Optional.of(new CatalogueApi.ProduitInfo(1L, 10L, 1L, "Cat", "Produit", "", null, null, java.util.List.of())));

        GroupeService.Demande sansPays = new GroupeService.Demande(
                "Titre", 1L, 100, Instant.parse("2026-11-28T12:00:00Z"),
                BigDecimal.valueOf(1000), BigDecimal.valueOf(100), BigDecimal.valueOf(50), BigDecimal.ZERO,
                15, "politique", 5, null);

        ErreurMetier err = assertThrows(ErreurMetier.class, () -> groupeService.creer(10L, sansPays));
        assertEquals(CodeErreur.DONNEES_INVALIDES, err.code());
        assertEquals("RG-PAYS", err.regle());
    }

    @Test
    void creationRefuseeSiPaysOrigineInconnu() {
        when(identite.exigerActif(10L)).thenReturn(new IdentiteApi.ActeurInfo(10L, "GROSSISTE", "ACTIF", "Grossiste", "+22370000010"));
        when(catalogue.produit(1L)).thenReturn(Optional.of(new CatalogueApi.ProduitInfo(1L, 10L, 1L, "Cat", "Produit", "", "XX", null, java.util.List.of())));
        when(paysRepository.findById("XX")).thenReturn(Optional.empty());

        GroupeService.Demande paysInconnu = new GroupeService.Demande(
                "Titre", 1L, 100, Instant.parse("2026-11-28T12:00:00Z"),
                BigDecimal.valueOf(1000), BigDecimal.valueOf(100), BigDecimal.valueOf(50), BigDecimal.ZERO,
                15, "politique", 5, "XX");

        ErreurMetier err = assertThrows(ErreurMetier.class, () -> groupeService.creer(10L, paysInconnu));
        assertEquals(CodeErreur.DONNEES_INVALIDES, err.code());
    }

    @Test
    void creationAccepteeAvecNomDePaysFrancais() {
        when(identite.exigerActif(10L)).thenReturn(new IdentiteApi.ActeurInfo(10L, "GROSSISTE", "ACTIF", "Grossiste", "+22370000010"));
        when(catalogue.produit(1L)).thenReturn(Optional.of(new CatalogueApi.ProduitInfo(1L, 10L, 1L, "Cat", "Produit", "", "Turquie", null, java.util.List.of())));
        Pays turquie = new Pays("TR", "TUR", "Turquie", 38.9637, 35.2433, true);
        when(paysRepository.findAll()).thenReturn(java.util.List.of(turquie));
        when(paysRepository.findById("TR")).thenReturn(Optional.of(turquie));

        GroupeAchat gSimule = new GroupeAchat(null, 10L, 1L, "Titre", "TR", 100, BigDecimal.valueOf(1150),
                Instant.parse("2026-10-28T12:00:00Z"), Instant.parse("2026-11-28T12:00:00Z"));
        org.springframework.test.util.ReflectionTestUtils.setField(gSimule, "id", 99L);
        when(groupes.save(any(GroupeAchat.class))).thenReturn(gSimule);
        when(groupes.findById(any())).thenReturn(Optional.of(gSimule));
        when(grilles.findByGroupeId(any())).thenReturn(Optional.of(new ml.dogo.groupeachat.persistence.GrilleTarifaire(99L, new ml.dogo.groupeachat.domain.CalculPrix.Composantes(BigDecimal.valueOf(1000), BigDecimal.valueOf(100), BigDecimal.valueOf(50), BigDecimal.ZERO, BigDecimal.ZERO), BigDecimal.valueOf(0.05))));
        when(conditions.findByGroupeId(any())).thenReturn(Optional.of(new ml.dogo.groupeachat.persistence.ConditionCommerciale(99L, 15, "politique", 5)));

        GroupeService.Demande demande = new GroupeService.Demande(
                "Titre", 1L, 100, Instant.parse("2026-11-28T12:00:00Z"),
                BigDecimal.valueOf(1000), BigDecimal.valueOf(100), BigDecimal.valueOf(50), BigDecimal.ZERO,
                15, "politique", 5, null); // paysOrigineCode null -> hérité de produit.paysOrigine ("Turquie")

        GroupeService.GroupeVue vue = groupeService.creer(10L, demande);
        assertEquals("TR", vue.paysOrigineCode());
        assertEquals("Turquie", vue.paysOrigineNom());
    }

    @Test
    void publicationRefuseeSiGroupeSansPays() {
        // Un ancien groupe sans pays_origine_code
        GroupeAchat g = new GroupeAchat(
                null, 10L, 1L, "Ancien Groupe", null, 100, BigDecimal.valueOf(1000),
                Instant.parse("2026-10-01T10:00:00Z"), Instant.parse("2026-11-01T10:00:00Z"));
        // Simuler statut EN_VALIDATION
        org.springframework.test.util.ReflectionTestUtils.setField(g, "statut", StatutGroupe.EN_VALIDATION);
        g.validerDisponibilite();

        when(groupes.findById(55L)).thenReturn(Optional.of(g));

        ErreurMetier err = assertThrows(ErreurMetier.class, () -> groupeService.decider(1L, 55L, true, "OK"));
        assertEquals(CodeErreur.DONNEES_INVALIDES, err.code());
        assertEquals("RG-PAYS", err.regle());
    }
}
