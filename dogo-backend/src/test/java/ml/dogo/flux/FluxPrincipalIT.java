package ml.dogo.flux;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/**
 * Parcours complet de la plateforme, de la création d'un groupe au retrait des marchandises et au portefeuille du
 * courtier : c'est la vérification de bout en bout des règles RG-16 à RG-59.
 *
 * <p>Prérequis : MySQL local ; la base {@code dogo_test} est créée puis vidée et reconstruite à chaque exécution
 * (variables DB_USER / DB_PASSWORD comme pour l'application). Profil « demo » : données d'exemple, SMS et Mobile Money
 * simulés. À lancer avec {@code mvn verify}.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:mysql://localhost:3306/karavan_test?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&createDatabaseIfNotExist=true",
        "spring.flyway.clean-disabled=false",
        "dogo.retrait.max-tentatives=3"})
@AutoConfigureMockMvc
@ActiveProfiles("demo")
@Import(FluxPrincipalIT.BaseVierge.class)
class FluxPrincipalIT {

    @TestConfiguration
    static class BaseVierge {
        @Bean
        FlywayMigrationStrategy reconstruire() {
            return flyway -> {
                flyway.clean();
                flyway.migrate();
            };
        }
    }

    private static final String PIN = "Dogo2026!";

    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;

    // ------------------------------------------------------------------ le scénario

    @Test
    void parcoursCompletDuGroupeAuRetraitEtAuPortefeuille() throws Exception {
        // Aucun mot de passe « universel » : seul le secret propre au compte ouvre une session (RG-07)
        for (String passePartout : new String[] {"1234", "2580"}) {
            appeler(HttpMethod.POST, "/api/auth/connexion", null,
                    Map.of("telephone", "+22370000001", "pin", passePartout), 401);
        }
        String technique = connecter("+22370000001");
        String grossiste = connecter("+22371000001");
        String courtier = connecter("+22372000001");
        String[] commercants = {connecter("+22373000001"), connecter("+22373000002"), connecter("+22373000003")};
        int[] quantites = {4, 3, 3};

        // --- création du groupe, circuit de validation (RG-16 à RG-20)
        JsonNode produit = appeler(HttpMethod.GET, "/api/catalogue/produits", grossiste, null, 200).get(0);
        long produitId = produit.get("id").asLong();
        long varianteId = produit.get("variantes").get(0).get("id").asLong();

        // le courtier choisit le produit dans le catalogue des grossistes actifs (RG-16)
        JsonNode disponibles = appeler(HttpMethod.GET, "/api/catalogue/produits-disponibles", courtier, null, 200);
        assertTrue(disponibles.findValues("id").stream().anyMatch(id -> id.asLong() == produitId));
        appeler(HttpMethod.GET, "/api/catalogue/produits-disponibles", grossiste, null, 403);

        appeler(HttpMethod.POST, "/api/groupes", commercants[0], groupe(produitId), 403);  // un commerçant ne crée pas de groupe
        JsonNode g = appeler(HttpMethod.POST, "/api/groupes", courtier, groupe(produitId), 201);
        long groupeId = g.get("id").asLong();
        assertEquals("BROUILLON", g.get("statut").asText());

        assertEquals("EN_VALIDATION", appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/soumission", courtier, null, 200).get("statut").asText());
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/disponibilite", grossiste, null, 200);
        // le grossiste retrouve tous les groupes montés sur ses produits
        JsonNode duGrossiste = appeler(HttpMethod.GET, "/api/groupes/du-grossiste", grossiste, null, 200);
        assertTrue(duGrossiste.findValues("id").stream().anyMatch(id -> id.asLong() == groupeId));
        appeler(HttpMethod.GET, "/api/groupes/du-grossiste", courtier, null, 403);
        appeler(HttpMethod.POST, "/api/admin/groupes/" + groupeId + "/publication", technique,
                Map.of("approuve", true, "commentaire", "ok"), 200);
        assertEquals("OUVERT", appeler(HttpMethod.GET, "/api/groupes/" + groupeId, courtier, null, 200).get("statut").asText());

        // --- participation, paiement, séquestre (RG-23 à RG-38)
        long[] participations = new long[3];
        for (int i = 0; i < 3; i++) {
            JsonNode p = appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/participations", commercants[i],
                    Map.of("varianteId", varianteId, "quantite", quantites[i]), 201);
            participations[i] = p.get("id").asLong();
            assertEquals("RESERVEE", p.get("statut").asText());
        }
        // la réservation ne dépasse jamais la cible (RG-23) : le groupe est plein, un quatrième acheteur est refusé
        assertEquals(10, appeler(HttpMethod.GET, "/api/groupes/" + groupeId, courtier, null, 200).get("quantiteReservee").asInt());
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/participations", commercants[0],
                Map.of("varianteId", varianteId, "quantite", 1), 409);

        for (int i = 0; i < 3; i++) {
            JsonNode paiement = appeler(HttpMethod.POST, "/api/participations/" + participations[i] + "/paiement", commercants[i],
                    Map.of(), 200, "Idempotency-Key", UUID.randomUUID().toString());
            long paiementId = paiement.get("id").asLong();
            JsonNode resultat = appeler(HttpMethod.POST, "/api/dev/mobile-money/" + paiementId + "/succes", technique, null, 200);  // simulateur réservé à ADMIN_CREER
            assertEquals("TRAITE", resultat.get("resultat").asText());
            assertEquals("CONFIRMEE", appeler(HttpMethod.GET, "/api/participations/" + participations[i], commercants[i], null, 200)
                    .get("statut").asText());
        }

        // --- objectif atteint : les commandes existent (RG-21, RG-44)
        assertEquals("OBJECTIF_ATTEINT", appeler(HttpMethod.GET, "/api/groupes/" + groupeId, courtier, null, 200).get("statut").asText());
        JsonNode chezGrossiste = appeler(HttpMethod.GET, "/api/groupes/" + groupeId + "/commandes", grossiste, null, 200);
        assertEquals(3, chezGrossiste.size());
        chezGrossiste.forEach(c -> assertTrue(c.get("commercantId").isNull(), "le grossiste ne voit pas l'identité des acheteurs (RG-71)"));
        long[] commandes = new long[3];
        for (int i = 0; i < 3; i++) {
            JsonNode mes = appeler(HttpMethod.GET, "/api/moi/commandes", commercants[i], null, 200);
            assertEquals(1, mes.size());
            assertEquals("CREEE", mes.get(0).get("statut").asText());
            commandes[i] = mes.get(0).get("id").asLong();
        }

        // --- acheminement (RG-50 à RG-53)
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/expedition", courtier, null, 409);   // pas encore préparées
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/preparation", courtier, null, 200);
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/expedition", courtier, null, 200);
        assertEquals("EN_EXPEDITION", appeler(HttpMethod.GET, "/api/groupes/" + groupeId, courtier, null, 200).get("statut").asText());

        // suivi du convoi : ACHETE -> CHEZ_TRANSITAIRE -> EN_TRANSIT <-> BLOQUE_DOUANE -> ARRIVE
        // Étape 1 : sécurité - un commerçant ne peut ni créer ni modifier le convoi du courtier
        appeler(HttpMethod.POST, "/api/convois", commercants[0],
                Map.of("groupeId", groupeId, "reference", "CNV-HACK", "transporteur", "Fret Demo"), 403);

        long convoiId = appeler(HttpMethod.POST, "/api/convois", courtier,
                Map.of("groupeId", groupeId, "reference", "CNV-" + groupeId, "transporteur", "Fret Demo"), 201).get("id").asLong();

        // Le commerçant et le grossiste du groupe voient le convoi en lecture seule
        assertEquals(1, appeler(HttpMethod.GET, "/api/convois", commercants[0], null, 200).size());
        assertEquals(1, appeler(HttpMethod.GET, "/api/convois", grossiste, null, 200).size());

        // Modification interdite aux non-courtiers
        appeler(HttpMethod.POST, "/api/convois/" + convoiId + "/transitaire", commercants[0], Map.of("localisation", "Istanbul"), 403);

        appeler(HttpMethod.POST, "/api/convois/" + convoiId + "/transit", courtier, null, 409);  // pas encore chez le transitaire
        appeler(HttpMethod.POST, "/api/convois/" + convoiId + "/transitaire", courtier, Map.of("localisation", "Istanbul"), 200);
        appeler(HttpMethod.POST, "/api/convois/" + convoiId + "/transit", courtier, null, 200);
        appeler(HttpMethod.POST, "/api/convois/" + convoiId + "/douane", courtier, Map.of("localisation", "Kati"), 200);
        appeler(HttpMethod.POST, "/api/convois/" + convoiId + "/transit", courtier, null, 200);
        JsonNode convoi = appeler(HttpMethod.POST, "/api/convois/" + convoiId + "/arrivee", courtier, null, 200);
        assertEquals("ARRIVE", convoi.get("statut").asText());
        assertEquals(6, convoi.get("evenements").size());
        appeler(HttpMethod.POST, "/api/admin/groupes/" + groupeId + "/reception", courtier, null, 403);  // réservé aux administrateurs
        appeler(HttpMethod.POST, "/api/admin/groupes/" + groupeId + "/reception", technique, null, 200);
        assertEquals("LIVRE", appeler(HttpMethod.GET, "/api/groupes/" + groupeId, courtier, null, 200).get("statut").asText());

        long pointId = appeler(HttpMethod.GET, "/api/points-retrait", courtier, null, 200).get(0).get("id").asLong();
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/reception-point-retrait", courtier, Map.of("pointRetraitId", pointId), 200);

        // --- code de retrait : le PIN n'est jamais relisible, le QR seulement (RG-53, RG-71)
        JsonNode code0 = appeler(HttpMethod.GET, "/api/commandes/" + commandes[0] + "/code-retrait", commercants[0], null, 200);
        assertFalse(code0.has("pin"));
        String qr0 = code0.get("qrToken").asText();
        assertEquals(64, qr0.length());
        appeler(HttpMethod.GET, "/api/commandes/" + commandes[0] + "/code-retrait", commercants[1], null, 404);  // pas la commande de l'autre
        appeler(HttpMethod.POST, "/api/retraits/valider", commercants[1], Map.of("qrToken", qr0), 403);        // un commerçant ne valide pas

        // --- trois PIN erronés bloquent le code (RG-54) ; le bloqué ne se rouvre qu'avec l'administrateur
        String mauvaisPin = "12ab56";
        appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("commandeId", commandes[0], "pin", mauvaisPin), 400);
        appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("commandeId", commandes[0], "pin", mauvaisPin), 400);
        appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("commandeId", commandes[0], "pin", mauvaisPin), 423);
        appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("qrToken", qr0), 423);              // même le bon QR
        appeler(HttpMethod.POST, "/api/commandes/" + commandes[0] + "/code-retrait/regeneration", courtier, null, 403);
        JsonNode nouveau = appeler(HttpMethod.POST, "/api/commandes/" + commandes[0] + "/code-retrait/regeneration", technique, null, 200);
        String qrNeuf = nouveau.get("qrToken").asText();
        assertNotEquals(qr0, qrNeuf);
        appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("qrToken", qr0), 400);               // l'ancien jeton n'existe plus

        // --- retraits : le séquestre est libéré à chaque collecte, jamais avant (RG-36, RG-37, RG-55)
        BigDecimal prix = new BigDecimal(appeler(HttpMethod.GET, "/api/groupes/" + groupeId, courtier, null, 200)
                .get("prixUnitaire").asText());
        BigDecimal total = prix.multiply(BigDecimal.TEN);
        assertEquals(0, total.compareTo(solde(courtier, "soldeBloque")), "tout l'argent est en séquestre avant les retraits");
        assertEquals(0, solde(courtier, "soldeDisponible").signum(), "rien n'est disponible avant la première collecte");

        JsonNode retrait0 = appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("qrToken", qrNeuf), 200);
        assertEquals("COLLECTEE", retrait0.get("statut").asText());
        appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("qrToken", qrNeuf), 409);            // déjà collectée
        BigDecimal apresUn = solde(courtier, "soldeDisponible");
        assertTrue(apresUn.signum() > 0);
        assertEquals(0, total.subtract(prix.multiply(BigDecimal.valueOf(quantites[0]))).compareTo(solde(courtier, "soldeBloque")),
                "seule la part de la commande collectée est sortie du séquestre");

        for (int i = 1; i < 3; i++) {
            String qr = appeler(HttpMethod.GET, "/api/commandes/" + commandes[i] + "/code-retrait", commercants[i], null, 200)
                    .get("qrToken").asText();
            appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("qrToken", qr), 200);
        }
        assertEquals(0, solde(courtier, "soldeBloque").signum(), "le séquestre est vide une fois tout collecté");
        BigDecimal disponible = solde(courtier, "soldeDisponible");
        assertTrue(disponible.compareTo(apresUn) > 0);
        assertTrue(disponible.compareTo(total) < 0, "la plateforme a prélevé ses frais (RG-37)");
        assertEquals("TERMINE", appeler(HttpMethod.GET, "/api/groupes/" + groupeId, courtier, null, 200).get("statut").asText());

        // --- le courtier retire une partie de ses fonds (RG-41), une clé d'idempotence évite le double retrait
        BigDecimal montant = new BigDecimal("1000");
        BigDecimal avantRetrait = solde(courtier, "soldeDisponible");
        String cle = UUID.randomUUID().toString();
        appeler(HttpMethod.POST, "/api/moi/portefeuille/retraits", courtier, Map.of("montant", montant), 200, "Idempotency-Key", cle);
        appeler(HttpMethod.POST, "/api/moi/portefeuille/retraits", courtier, Map.of("montant", montant), 200, "Idempotency-Key", cle);
        assertEquals(0, avantRetrait.subtract(montant).compareTo(solde(courtier, "soldeDisponible")));

        // --- le journal d'audit reste intact (RG-66, RG-67)
        assertTrue(appeler(HttpMethod.GET, "/api/admin/audit/verification", technique, null, 200).get("chaineIntacte").asBoolean());
    }

    // ------------------------------------------------------------------ outils

    private Map<String, Object> groupe(long produitId) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("produitId", produitId);
        m.put("quantiteCible", 10);
        m.put("dateLimite", Instant.now().plus(2, ChronoUnit.DAYS).toString());
        m.put("marchandise", new BigDecimal("5000"));
        m.put("transport", new BigDecimal("500"));
        m.put("douane", new BigDecimal("300"));
        m.put("autres", new BigDecimal("200"));
        m.put("delaiLivraisonJours", 30);
        m.put("politiqueAnnulation", "Annulation possible avant l'objectif atteint");
        m.put("quantiteMinParCommercant", 1);
        return m;
    }

    private String connecter(String telephone) throws Exception {
        return appeler(HttpMethod.POST, "/api/auth/connexion", null, Map.of("telephone", telephone, "pin", PIN), 200)
                .get("jeton").asText();
    }

    private BigDecimal solde(String jeton, String champ) throws Exception {
        return new BigDecimal(appeler(HttpMethod.GET, "/api/moi/portefeuille", jeton, null, 200).get(champ).asText());
    }

    /** Envoie une requête, vérifie le statut HTTP et renvoie le corps JSON (ou un nœud vide). */
    private JsonNode appeler(HttpMethod methode, String url, String jeton, Object corps, int statutAttendu, String... entetes)
            throws Exception {
        MockHttpServletRequestBuilder requete = MockMvcRequestBuilders.request(methode, url).accept(MediaType.APPLICATION_JSON);
        if (jeton != null) {
            requete.header("Authorization", "Bearer " + jeton);
        }
        for (int i = 0; i + 1 < entetes.length; i += 2) {
            requete.header(entetes[i], entetes[i + 1]);
        }
        if (corps != null) {
            requete.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(corps));
        } else if (methode == HttpMethod.POST) {
            requete.contentType(MediaType.APPLICATION_JSON).content("{}");
        }
        MockHttpServletResponse reponse = mvc.perform(requete).andReturn().getResponse();
        String texte = reponse.getContentAsString();
        assertEquals(statutAttendu, reponse.getStatus(),
                methode + " " + url + " -> " + reponse.getStatus() + " " + texte);
        return texte.isBlank() ? json.createObjectNode() : json.readTree(texte);
    }
}
