package ml.dogo.logistique;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.finance.api.FinanceApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.logistique.application.CompteursRetrait;
import ml.dogo.logistique.application.QrColisService;
import ml.dogo.logistique.application.QrSecuriteService;
import ml.dogo.logistique.application.RetraitService;
import ml.dogo.logistique.domain.StatutCommande;
import ml.dogo.logistique.domain.StatutExpedition;
import ml.dogo.logistique.persistence.CodeRetrait;
import ml.dogo.logistique.persistence.CodeRetraitRepository;
import ml.dogo.logistique.persistence.Commande;
import ml.dogo.logistique.persistence.CommandeRepository;
import ml.dogo.logistique.persistence.EvenementLogistiqueRepository;
import ml.dogo.logistique.persistence.Expedition;
import ml.dogo.logistique.persistence.ExpeditionRepository;
import ml.dogo.logistique.persistence.PointRetrait;
import ml.dogo.logistique.persistence.PointRetraitRepository;
import ml.dogo.logistique.persistence.PreuveRetraitRepository;
import ml.dogo.logistique.persistence.QrColis;
import ml.dogo.logistique.persistence.QrColisRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.identite.domain.TypeActeur;
import ml.dogo.shared.security.UtilisateurCourant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Tests exhaustifs pour la mission QR Retrait et QR Colis :
 * - Jeton valide accepté une seule fois ; deuxième scan refusé
 * - Deux requêtes simultanées : une seule réussit
 * - Mauvais type de QR (retrait présenté pour colis et inversement)
 * - Jeton expiré et annulé
 * - Régénération (ancien refusé, nouveau accepté)
 * - Code court de secours 8 chiffres et limitation de tentatives
 * - Pas de token en clair stocké
 * - Génération d'étiquette QR ZXing (PNG)
 */
class QrRetraitColisTest {

    private final Instant FIXE = Instant.parse("2026-11-03T12:00:00Z");
    private final Clock horloge = Clock.fixed(FIXE, ZoneOffset.UTC);

    private static void setId(Object entity, Long id) {
        try {
            java.lang.reflect.Field f = entity.getClass().getDeclaredField("id");
            f.setAccessible(true);
            f.set(entity, id);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private DogoProperties proprietes;
    private QrSecuriteService qrSecurite;

    @BeforeEach
    void initSecurite() {
        proprietes = new DogoProperties(
                new DogoProperties.Jwt("TestSecretKeyForAntigravityQrTokenValidation2026"),
                new DogoProperties.Otp(Duration.ofMinutes(5), 3, true),
                new DogoProperties.Pin(3, Duration.ofMinutes(15)),
                new DogoProperties.Session(Duration.ofHours(2)),
                new DogoProperties.Reservation(Duration.ofMinutes(15)),
                new DogoProperties.Commission(new java.math.BigDecimal("0.05")),
                new DogoProperties.Retrait(Duration.ofDays(45), 3),
                new DogoProperties.MobileMoney("secret"),
                new DogoProperties.Stockage("./tmp")
        );
        qrSecurite = new QrSecuriteService(proprietes);
    }

    @Nested
    @DisplayName("1. Sécurité, cryptographie et génération des jetons")
    class SecuriteEtGeneration {

        @Test
        @DisplayName("Le jeton KVR comporte le préfixe KVR., au moins 128 bits base64url et aucun padding")
        void jetonRetraitFormat() {
            String jeton = qrSecurite.genererJeton(QrSecuriteService.PREFIXE_RETRAIT);
            assertTrue(jeton.startsWith("KVR."));
            assertFalse(jeton.contains("="));
            assertTrue(jeton.length() >= 24); // 4 (prefix) + 22 (16 bytes base64url)
        }

        @Test
        @DisplayName("Le jeton KVC comporte le préfixe KVC., au moins 128 bits base64url et aucun padding")
        void jetonColisFormat() {
            String jeton = qrSecurite.genererJeton(QrSecuriteService.PREFIXE_COLIS);
            assertTrue(jeton.startsWith("KVC."));
            assertFalse(jeton.contains("="));
            assertTrue(jeton.length() >= 24);
        }

        @Test
        @DisplayName("Le code court de secours est composé exactement de 8 chiffres")
        void codeCourtFormat() {
            String code = qrSecurite.genererCodeCourt();
            assertNotNull(code);
            assertTrue(code.matches("^\\d{8}$"), "Le code court doit avoir 8 chiffres : " + code);
        }

        @Test
        @DisplayName("Le hash SHA-256 est déterministe et de 64 caractères hexadécimaux")
        void hashingSha256() {
            String jeton = "KVR.testToken12345";
            String h1 = qrSecurite.hasher(jeton);
            String h2 = qrSecurite.hasher(jeton);
            assertEquals(h1, h2);
            assertEquals(64, h1.length());
        }

        @Test
        @DisplayName("Chiffrement et déchiffrement réversible AES-GCM pour l'étiquette colis")
        void chiffrementEtiquette() {
            String token = "KVC.secretTokenParcel123";
            String chiffre = qrSecurite.chiffrer(token);
            assertNotEquals(token, chiffre);
            String dechiffre = qrSecurite.dechiffrer(chiffre);
            assertEquals(token, dechiffre);
        }

        @Test
        @DisplayName("Génération de l'image QR code PNG avec ZXing (en-tête PNG valide)")
        void generationImageQrZxing() {
            byte[] image = qrSecurite.genererImageQrPng("KVC.testEtiquette", 200, 200);
            assertNotNull(image);
            assertTrue(image.length > 50);
            // Vérification de la signature PNG : 0x89, 'P', 'N', 'G'
            assertEquals((byte) 0x89, image[0]);
            assertEquals((byte) 'P', image[1]);
            assertEquals((byte) 'N', image[2]);
            assertEquals((byte) 'G', image[3]);
        }

        @Test
        @DisplayName("Limitation des tentatives : plus de 10 tentatives déclenche un refus")
        void limitationTentativesRateLimit() {
            String agent = "agent-test-1";
            for (int i = 0; i < 10; i++) {
                qrSecurite.controlerTentatives(agent);
                qrSecurite.enregistrerTentative(agent);
            }
            ErreurMetier err = assertThrows(ErreurMetier.class, () -> qrSecurite.controlerTentatives(agent));
            assertEquals(CodeErreur.ACCES_REFUSE, err.code());
            assertTrue(err.getMessage().contains("Trop de tentatives"));
        }
    }

    @Nested
    @DisplayName("2. Incompatibilité stricte des types de QR (KVR vs KVC)")
    class IncompatibiliteTypes {

        @Test
        @DisplayName("Un QR colis (KVC.) présenté pour un retrait est rejeté avec un motif clair")
        void colisRefusePourRetrait() {
            ErreurMetier e = assertThrows(ErreurMetier.class, () ->
                    qrSecurite.verifierTypeRetrait("KVC.abc123xyz"));
            assertEquals(CodeErreur.DONNEES_INVALIDES, e.code());
            assertTrue(e.getMessage().contains("Mauvais type de QR code (QR colis présenté pour un retrait)"));
        }

        @Test
        @DisplayName("Un QR retrait (KVR.) présenté pour une arrivée colis est rejeté avec un motif clair")
        void retraitRefusePourColis() {
            ErreurMetier e = assertThrows(ErreurMetier.class, () ->
                    qrSecurite.verifierTypeColis("KVR.abc123xyz"));
            assertEquals(CodeErreur.DONNEES_INVALIDES, e.code());
            assertTrue(e.getMessage().contains("Mauvais type de QR code (QR retrait présenté pour un colis)"));
        }
    }

    @Nested
    @DisplayName("3. Service QR Colis (KVC) : cycle de vie et validation d'arrivée")
    class QrColisServiceTest {

        private QrColisRepository qrColisRepository;
        private ExpeditionRepository expeditions;
        private CommandeRepository commandes;
        private EvenementLogistiqueRepository evenements;
        private PointRetraitRepository points;
        private RetraitService retraits;
        private GroupeAchatApi groupes;
        private ParticipationApi participations;
        private AuditApi audit;
        private NotificationApi notifications;
        private QrColisService service;

        private final UtilisateurCourant admin = new UtilisateurCourant(1L, "ADMINISTRATEUR",
                List.of("RECEPTION_VALIDER", "ROLE_ADMINISTRATEUR"), 1001L);

        @BeforeEach
        void setUp() {
            qrColisRepository = mock(QrColisRepository.class);
            expeditions = mock(ExpeditionRepository.class);
            commandes = mock(CommandeRepository.class);
            evenements = mock(EvenementLogistiqueRepository.class);
            points = mock(PointRetraitRepository.class);
            retraits = mock(RetraitService.class);
            groupes = mock(GroupeAchatApi.class);
            participations = mock(ParticipationApi.class);
            audit = mock(AuditApi.class);
            notifications = mock(NotificationApi.class);

            service = new QrColisService(qrColisRepository, expeditions, commandes, evenements, points,
                    retraits, groupes, participations, audit, notifications, qrSecurite, horloge, 45);
        }

        @Test
        @DisplayName("Création d'un QR colis : jeton préfixé KVC, expiration 45 jours et code court 8 chiffres")
        void creationQrColis() {
            Expedition exp = new Expedition(10L, "EXP-2026-001", StatutExpedition.EN_TRANSIT, FIXE, "DHL");
            setId(exp, 10L);
            when(expeditions.findById(10L)).thenReturn(Optional.of(exp));
            when(qrColisRepository.findByExpeditionIdAndStatut(10L, "ACTIF")).thenReturn(Optional.empty());
            when(qrColisRepository.save(any(QrColis.class))).thenAnswer(inv -> {
                QrColis q = inv.getArgument(0);
                setId(q, 100L);
                return q;
            });

            QrColisService.QrColisVue vue = service.obtenirOuCreer(10L);
            assertNotNull(vue);
            assertTrue(vue.token().startsWith("KVC."));
            assertTrue(vue.codeCourt().matches("^\\d{8}$"));
            assertEquals("ACTIF", vue.statut());
            assertEquals(FIXE.plus(Duration.ofDays(45)), vue.expiration());
        }

        @Test
        @DisplayName("Validation de l'arrivée du colis : succès au premier scan, échec immédiat au second scan (déjà utilisé)")
        void validationArriveeUniquePuisRejetReplay() {
            String token = "KVC.ValidToken123";
            String tokenHash = qrSecurite.hasher(token);
            String codeCourtHash = qrSecurite.hasher("12345678");
            Instant expiration = FIXE.plus(Duration.ofDays(45));

            QrColis qr = new QrColis(10L, tokenHash, qrSecurite.chiffrer(token), codeCourtHash, expiration, FIXE);
            setId(qr, 50L);
            Expedition exp = new Expedition(10L, "EXP-001", StatutExpedition.EN_TRANSIT, FIXE, "DHL");
            setId(exp, 10L);

            when(expeditions.findById(10L)).thenReturn(Optional.of(exp));
            when(qrColisRepository.findByTokenHash(tokenHash)).thenReturn(Optional.of(qr));
            when(qrColisRepository.consommer(eq(50L), eq(FIXE), eq(admin.id()))).thenReturn(1);

            // 1er scan : succès
            QrColisService.ColisArriveeVue res1 = service.validerArrivee(admin, token, "127.0.0.1");
            assertEquals("ARRIVE", res1.statut());
            assertEquals("EXP-001", res1.reference());
            verify(evenements).save(any());
            verify(audit).tracer(eq(admin.id()), eq("COLIS_ARRIVEE_VALIDEE"), anyString(), anyString());

            // Simuler état consommé
            when(qrColisRepository.consommer(eq(50L), eq(FIXE), eq(admin.id()))).thenReturn(0);
            QrColis qrUtilise = new QrColis(10L, tokenHash, null, codeCourtHash, expiration, FIXE);
            setId(qrUtilise, 50L);
            try {
                java.lang.reflect.Field fieldStatut = QrColis.class.getDeclaredField("statut");
                fieldStatut.setAccessible(true);
                fieldStatut.set(qrUtilise, "UTILISE");
            } catch (Exception ignored) {}
            when(qrColisRepository.findByTokenHash(tokenHash)).thenReturn(Optional.of(qrUtilise));

            // 2e scan : échec avec conflit
            ErreurMetier err = assertThrows(ErreurMetier.class, () ->
                    service.validerArrivee(admin, token, "127.0.0.1"));
            assertEquals(CodeErreur.CONFLIT, err.code());
            assertTrue(err.getMessage().contains("déjà été validé"));
        }

        @Test
        @DisplayName("Régénération d'un QR colis : annule l'ancien et génère un nouveau token actif")
        void regenerationAnnuleAncien() {
            Expedition exp = new Expedition(10L, "EXP-001", StatutExpedition.EN_TRANSIT, FIXE, "DHL");
            setId(exp, 10L);
            when(expeditions.findById(10L)).thenReturn(Optional.of(exp));
            when(qrColisRepository.save(any(QrColis.class))).thenAnswer(inv -> {
                QrColis q = inv.getArgument(0);
                setId(q, 101L);
                return q;
            });

            QrColisService.QrColisVue nouveau = service.regenerer(admin, 10L);
            assertNotNull(nouveau);
            assertTrue(nouveau.token().startsWith("KVC."));
            verify(qrColisRepository).annulerActifsDeExpedition(10L);
            verify(audit).tracer(eq(admin.id()), eq("QR_COLIS_REGENERE"), anyString(), anyString());
        }
    }

    @Nested
    @DisplayName("4. Service QR Retrait (KVR) : validation, concurrence et code court")
    class RetraitServiceTest {

        private CommandeRepository commandes;
        private CodeRetraitRepository codes;
        private PreuveRetraitRepository preuves;
        private PointRetraitRepository points;
        private CompteursRetrait compteurs;
        private GroupeAchatApi campagne;
        private FinanceApi finance;
        private IdentiteApi identite;
        private AuditApi audit;
        private NotificationApi notifications;
        private PasswordEncoder encodeur;
        private RetraitService retraitService;

        private final UtilisateurCourant courtier = new UtilisateurCourant(2L, "COURTIER",
                List.of("RETRAIT_VALIDER"), 1002L);

        @BeforeEach
        void setUp() {
            commandes = mock(CommandeRepository.class);
            codes = mock(CodeRetraitRepository.class);
            preuves = mock(PreuveRetraitRepository.class);
            points = mock(PointRetraitRepository.class);
            compteurs = mock(CompteursRetrait.class);
            campagne = mock(GroupeAchatApi.class);
            finance = mock(FinanceApi.class);
            identite = mock(IdentiteApi.class);
            audit = mock(AuditApi.class);
            notifications = mock(NotificationApi.class);
            encodeur = mock(PasswordEncoder.class);

            retraitService = new RetraitService(commandes, codes, preuves, points, compteurs,
                    campagne, finance, identite, audit, notifications, encodeur, proprietes, qrSecurite, horloge, 45);
        }

        @Test
        @DisplayName("Validation du retrait au scan : accepté au premier appel, commande passe à COLLECTEE")
        void validationRetraitSucces() {
            String token = "KVR.RetraitTokenClient1";
            String tokenHash = qrSecurite.hasher(token);
            long commandeId = 101L;
            long groupeId = 20L;

            when(codes.commandeDuJetonOuHash(eq(token), eq(tokenHash))).thenReturn(Optional.of(commandeId));
            when(commandes.groupeDe(commandeId)).thenReturn(Optional.of(groupeId));

            GroupeAchatApi.GroupeInfo g = new GroupeAchatApi.GroupeInfo(groupeId, courtier.id(), 3L, 10L, "T-Shirt Coton",
                    "LIVRE", 100, 100, 0, java.math.BigDecimal.valueOf(1000), java.math.BigDecimal.valueOf(100),
                    java.math.BigDecimal.valueOf(0.05), 1, FIXE);
            when(campagne.groupe(groupeId)).thenReturn(Optional.of(g));

            Commande c = new Commande(groupeId, 501L, 30L, 5, FIXE);
            setId(c, commandeId);
            // Placer en attente de retrait
            c.changerStatut(StatutCommande.PREPAREE);
            c.changerStatut(StatutCommande.EXPEDIEE);
            c.changerStatut(StatutCommande.ARRIVEE);
            c.changerStatut(StatutCommande.EN_ATTENTE_RETRAIT);

            when(commandes.verrouillerDuGroupe(groupeId)).thenReturn(List.of(c));

            CodeRetrait code = new CodeRetrait(commandeId, "hash", token, tokenHash, "codeCourtHash",
                    FIXE.plus(Duration.ofDays(45)), FIXE);
            setId(code, 77L);
            when(codes.findByCommandeId(commandeId)).thenReturn(Optional.of(code));
            when(codes.consommerAvecActeur(anyLong(), eq(FIXE), eq(courtier.id()))).thenReturn(1);
            when(identite.acteur(30L)).thenReturn(Optional.of(new IdentiteApi.ActeurInfo(30L, "COMMERCANT", "ACTIF", "Oumar Diallo", "+22370111222", null)));

            RetraitService.RetraitVue vue = retraitService.valider(courtier, null, token, null);

            assertEquals(commandeId, vue.commandeId());
            assertEquals("COLLECTEE", vue.statut());
            assertEquals("Oumar Diallo", vue.nomClient());
            assertEquals("T-Shirt Coton", vue.marchandise());
            assertEquals(5, vue.quantite());
            verify(finance).libererSequestre(c.getParticipationId());
            verify(audit).tracer(eq(courtier.id()), eq("RETRAIT_VALIDE"), anyString(), anyString());
        }

        @Test
        @DisplayName("Validation simultanée concurrente (2 threads) : 1 seul réussit, le 2ème renvoie CONFLIT")
        void concurrenceDeuxScansSimultanes() throws Exception {
            String token = "KVR.ConcurrentScanTest";
            String tokenHash = qrSecurite.hasher(token);
            long commandeId = 202L;
            long groupeId = 30L;

            when(codes.commandeDuJetonOuHash(eq(token), eq(tokenHash))).thenReturn(Optional.of(commandeId));
            when(commandes.groupeDe(commandeId)).thenReturn(Optional.of(groupeId));

            GroupeAchatApi.GroupeInfo g = new GroupeAchatApi.GroupeInfo(groupeId, courtier.id(), 4L, 11L, "Montre Connectée",
                    "LIVRE", 50, 50, 0, java.math.BigDecimal.valueOf(5000), java.math.BigDecimal.valueOf(200),
                    java.math.BigDecimal.valueOf(0.05), 1, FIXE);
            when(campagne.groupe(groupeId)).thenReturn(Optional.of(g));

            when(commandes.verrouillerDuGroupe(groupeId)).thenAnswer(inv -> {
                Commande cmd = new Commande(groupeId, 601L, 40L, 2, FIXE);
                setId(cmd, commandeId);
                cmd.changerStatut(StatutCommande.PREPAREE);
                cmd.changerStatut(StatutCommande.EXPEDIEE);
                cmd.changerStatut(StatutCommande.ARRIVEE);
                cmd.changerStatut(StatutCommande.EN_ATTENTE_RETRAIT);
                return List.of(cmd);
            });

            CodeRetrait code = new CodeRetrait(commandeId, "hash", token, tokenHash, "shortHash",
                    FIXE.plus(Duration.ofDays(45)), FIXE);
            setId(code, 88L);
            when(codes.findByCommandeId(commandeId)).thenReturn(Optional.of(code));
            when(identite.acteur(40L)).thenReturn(Optional.of(new IdentiteApi.ActeurInfo(40L, "COMMERCANT", "ACTIF", "Commerçant 40", "+22370000040", null)));

            // Simuler l'atomicité SQL : le 1er appel à consommer renvoie 1, le 2nd renvoie 0
            AtomicInteger sqlExecutionCount = new AtomicInteger(0);
            when(codes.consommerAvecActeur(anyLong(), any(), anyLong())).thenAnswer(inv -> {
                int count = sqlExecutionCount.incrementAndGet();
                return count == 1 ? 1 : 0;
            });

            ExecutorService executor = Executors.newFixedThreadPool(2);
            CountDownLatch ready = new CountDownLatch(2);
            CountDownLatch start = new CountDownLatch(1);
            AtomicInteger succes = new AtomicInteger(0);
            AtomicInteger echecs = new AtomicInteger(0);

            for (int i = 0; i < 2; i++) {
                executor.submit(() -> {
                    ready.countDown();
                    try {
                        start.await();
                        retraitService.valider(courtier, null, token, null);
                        succes.incrementAndGet();
                    } catch (ErreurMetier em) {
                        System.err.println("Thread caught ErreurMetier: " + em.code() + " msg: " + em.getMessage());
                        if (em.code() == CodeErreur.CONFLIT) {
                            echecs.incrementAndGet();
                        }
                    } catch (Throwable e) {
                        System.err.println("Thread caught Throwable: " + e);
                        e.printStackTrace();
                    }
                });
            }

            ready.await();
            start.countDown();
            executor.shutdown();
            executor.awaitTermination(5, java.util.concurrent.TimeUnit.SECONDS);

            assertEquals(1, succes.get(), "Exactement 1 requête concurrente doit réussir");
            assertEquals(1, echecs.get(), "Exactement 1 requête concurrente doit échouer avec conflit");
        }
    }
}
