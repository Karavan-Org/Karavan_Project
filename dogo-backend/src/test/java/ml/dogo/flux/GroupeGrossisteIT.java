package ml.dogo.flux;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
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
 * Groupe d'achat porté par le grossiste lui-même, sans courtier : il le crée sur son produit (prix de gros repris),
 * sa soumission vaut attestation de stock, il partage le groupe publié, encaisse le séquestre, signale les étapes
 * d'acheminement et l'administrateur fait avancer les commandes jusqu'au retrait.
 *
 * <p>Même prérequis que {@link FluxPrincipalIT} (MySQL local, base {@code dogo_test} reconstruite).
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:mysql://localhost:3306/dogo_test?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&createDatabaseIfNotExist=true",
        "spring.flyway.clean-disabled=false",
        "dogo.test.scenario=groupe-grossiste"})
@AutoConfigureMockMvc
@ActiveProfiles("demo")
@Import(GroupeGrossisteIT.BaseVierge.class)
class GroupeGrossisteIT {

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

    @Test
    void leGrossisteMonteSonGroupeEtLAdministrateurSuitLAcheminement() throws Exception {
        String technique = connecter("+22370000001");
        String grossiste = connecter("+22371000001");
        String courtier = connecter("+22372000001");
        String commercant = connecter("+22373000001");
        String commercant2 = connecter("+22373000002");

        // --- le produit garde son prix de gros, qui servira de prix marchandise du groupe
        Map<String, Object> produit = new LinkedHashMap<>();
        produit.put("categorieId", 1);
        produit.put("nom", "Sandales Été");
        produit.put("paysOrigine", "Turquie");
        produit.put("prixGros", new BigDecimal("4000"));
        produit.put("variantes", List.of(Map.of("sku", "SAND-" + UUID.randomUUID().toString().substring(0, 8),
                "taille", "41", "couleur", "Noir", "qteDisponible", 20)));
        JsonNode p = appeler(HttpMethod.POST, "/api/catalogue/produits", grossiste, produit, 201);
        long produitId = p.get("id").asLong();
        long varianteId = p.get("variantes").get(0).get("id").asLong();
        assertEquals(0, new BigDecimal("4000").compareTo(p.get("prixGros").decimalValue()));

        // --- le grossiste ne voit pas le catalogue des autres, mais crée un groupe sur le sien
        appeler(HttpMethod.GET, "/api/catalogue/produits-disponibles", grossiste, null, 403);
        // un objectif au-delà du stock est refusé à la soumission (RG-13) et le groupe reste en brouillon
        long tropGrand = appeler(HttpMethod.POST, "/api/groupes", grossiste, groupe(produitId, 25), 201).get("id").asLong();
        appeler(HttpMethod.POST, "/api/groupes/" + tropGrand + "/soumission", grossiste, null, 409);
        assertEquals("BROUILLON", appeler(HttpMethod.GET, "/api/groupes/" + tropGrand, grossiste, null, 200).get("statut").asText());

        JsonNode cree = appeler(HttpMethod.POST, "/api/groupes", grossiste, groupe(produitId, 10), 201);
        long groupeId = cree.get("id").asLong();
        assertEquals("BROUILLON", cree.get("statut").asText());
        assertEquals("Sandales pour la rentrée", cree.get("titre").asText());
        assertTrue(cree.get("porteParGrossiste").asBoolean());
        assertTrue(cree.get("courtier").isNull());
        // la politique d'annulation est celle de la plateforme : le grossiste ne la fixe pas
        assertEquals(ml.dogo.groupeachat.application.GroupeService.POLITIQUE_ANNULATION_PLATEFORME,
                cree.get("conditions").get("politiqueAnnulation").asText());

        // un courtier ne pilote pas le groupe d'un grossiste
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/soumission", courtier, null, 404);

        // --- la soumission par le grossiste vaut attestation de stock (RG-18) : il ne reste que la publication
        JsonNode soumis = appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/soumission", grossiste, null, 200);
        assertEquals("EN_VALIDATION", soumis.get("statut").asText());
        assertTrue(soumis.get("disponibiliteValidee").asBoolean());
        appeler(HttpMethod.GET, "/api/groupes/" + groupeId, commercant, null, 404);   // pas encore publié
        appeler(HttpMethod.POST, "/api/admin/groupes/" + groupeId + "/publication", technique,
                Map.of("approuve", true, "commentaire", "ok"), 200);

        // --- le lien partagé mène au groupe : le commerçant l'ouvre et le rejoint
        JsonNode vu = appeler(HttpMethod.GET, "/api/groupes/" + groupeId, commercant, null, 200);
        assertEquals("OUVERT", vu.get("statut").asText());
        assertEquals("Sandales pour la rentrée", vu.get("titre").asText());
        assertTrue(appeler(HttpMethod.GET, "/api/groupes/mes-groupes", grossiste, null, 200)
                .findValues("id").stream().anyMatch(id -> id.asLong() == groupeId));

        for (String acheteur : new String[] {commercant, commercant2}) {   // RG-27 : 50 % de la cible au plus chacun
            long participationId = appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/participations", acheteur,
                    Map.of("varianteId", varianteId, "quantite", 5), 201).get("id").asLong();
            long paiementId = appeler(HttpMethod.POST, "/api/participations/" + participationId + "/paiement", acheteur,
                    Map.of(), 200, "Idempotency-Key", UUID.randomUUID().toString()).get("id").asLong();
            appeler(HttpMethod.POST, "/api/dev/mobile-money/" + paiementId + "/succes", technique, null, 200);
        }
        assertEquals("OBJECTIF_ATTEINT", appeler(HttpMethod.GET, "/api/groupes/" + groupeId, grossiste, null, 200)
                .get("statut").asText());

        // le séquestre est tenu dans le portefeuille du grossiste
        BigDecimal prix = new BigDecimal(vu.get("prixUnitaire").asText());
        BigDecimal total = prix.multiply(BigDecimal.TEN);
        assertEquals(0, total.compareTo(solde(grossiste, "soldeBloque")));

        // --- le grossiste achemine lui-même : il signale les étapes, l'administrateur met à jour le suivi
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/etapes", grossiste,
                Map.of("etape", "Colis expédiés", "commentaire", "Camion Bamako-Dakar"), 204);
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/etapes", courtier, Map.of("etape", "x"), 403);
        JsonNode etapes = appeler(HttpMethod.GET, "/api/groupes/" + groupeId + "/etapes", grossiste, null, 200);
        assertEquals(1, etapes.size());
        assertEquals("Colis expédiés", etapes.get(0).get("etape").asText());
        assertEquals(1, appeler(HttpMethod.GET, "/api/groupes/" + groupeId + "/etapes", technique, null, 200).size());
        appeler(HttpMethod.GET, "/api/groupes/" + groupeId + "/etapes", commercant, null, 403);
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/preparation", grossiste, null, 403);
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/preparation", courtier, null, 403);
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/preparation", technique, null, 200);
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/expedition", technique, null, 200);
        long convoiId = appeler(HttpMethod.POST, "/api/convois", technique,
                Map.of("groupeId", groupeId, "reference", "CNV-G" + groupeId, "transporteur", "Grossiste"), 201)
                .get("id").asLong();
        appeler(HttpMethod.POST, "/api/convois", grossiste,
                Map.of("groupeId", groupeId, "reference", "CNV-X" + groupeId, "transporteur", "x"), 403);
        appeler(HttpMethod.POST, "/api/convois/" + convoiId + "/transitaire", technique, Map.of("localisation", "Bamako"), 200);
        assertEquals(1, appeler(HttpMethod.GET, "/api/convois", commercant, null, 200).size());  // le commerçant suit le colis
        appeler(HttpMethod.POST, "/api/admin/groupes/" + groupeId + "/reception", technique, null, 200);
        long pointId = appeler(HttpMethod.GET, "/api/points-retrait", technique, null, 200).get(0).get("id").asLong();
        appeler(HttpMethod.POST, "/api/groupes/" + groupeId + "/reception-point-retrait", technique,
                Map.of("pointRetraitId", pointId), 200);

        // --- retrait validé par l'administrateur : le grossiste encaisse (moins les frais de plateforme)
        for (String acheteur : new String[] {commercant, commercant2}) {
            long commandeId = appeler(HttpMethod.GET, "/api/moi/commandes", acheteur, null, 200).get(0).get("id").asLong();
            String qr = appeler(HttpMethod.GET, "/api/commandes/" + commandeId + "/code-retrait", acheteur, null, 200)
                    .get("qrToken").asText();
            appeler(HttpMethod.POST, "/api/retraits/valider", courtier, Map.of("qrToken", qr), 403);
            appeler(HttpMethod.POST, "/api/retraits/valider", technique, Map.of("qrToken", qr), 200);
        }
        assertEquals("TERMINE", appeler(HttpMethod.GET, "/api/groupes/" + groupeId, grossiste, null, 200).get("statut").asText());
        assertEquals(0, solde(grossiste, "soldeBloque").signum());
        BigDecimal disponible = solde(grossiste, "soldeDisponible");
        assertTrue(disponible.signum() > 0 && disponible.compareTo(total) < 0);
        appeler(HttpMethod.POST, "/api/moi/moyens-paiement", grossiste,
                Map.of("numero", "+22371000001", "operateur", "ORANGE_MONEY", "parDefaut", true), 201);
        appeler(HttpMethod.POST, "/api/moi/portefeuille/retraits", grossiste, Map.of("montant", new BigDecimal("1000")), 200,
                "Idempotency-Key", UUID.randomUUID().toString());
    }

    // ------------------------------------------------------------------ outils

    private Map<String, Object> groupe(long produitId, int cible) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("titre", "Sandales pour la rentrée");
        m.put("produitId", produitId);
        m.put("quantiteCible", cible);
        m.put("dateLimite", Instant.now().plus(2, ChronoUnit.DAYS).toString());
        m.put("marchandise", new BigDecimal("4000"));
        m.put("transport", BigDecimal.ZERO);
        m.put("douane", BigDecimal.ZERO);
        m.put("autres", BigDecimal.ZERO);
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
