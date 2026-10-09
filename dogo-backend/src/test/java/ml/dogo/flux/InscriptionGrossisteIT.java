package ml.dogo.flux;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/**
 * Parcours d'arrivée d'un Grossiste tel que l'application mobile l'enchaîne : inscription, OTP, connexion,
 * dépôt du dossier KYC (RG-03, RG-04), validation (RG-05), puis upload d'une photo et création d'un produit.
 *
 * <p>Même base et mêmes prérequis que {@link FluxPrincipalIT} (MySQL local, base {@code dogo_test}).
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:mysql://localhost:3306/dogo_test?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&createDatabaseIfNotExist=true",
        "spring.flyway.clean-disabled=false",
        "dogo.retrait.max-tentatives=3"})
@AutoConfigureMockMvc
@ActiveProfiles("demo")
@Import(FluxPrincipalIT.BaseVierge.class)
class InscriptionGrossisteIT {

    /** Signatures minimales reconnues par le backend (le contenu n'est pas décodé). */
    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0};
    private static final byte[] PDF = "%PDF-1.4\n%%EOF".getBytes();
    private static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0x10, 'J', 'F', 'I', 'F'};

    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;

    @Test
    void grossisteSInscritDeposeSonDossierPuisAjouteUnProduit() throws Exception {
        String telephone = "+22379" + (100_000 + (System.nanoTime() % 900_000));
        String pin = "4826";

        // --- inscription (corps identique à celui envoyé par GrossisteInscriptionScreen)
        JsonNode inscrit = json(post("/api/auth/inscription", null, Map.of(
                "type", "GROSSISTE", "telephone", telephone, "nom", "Grand Dépôt Mandé", "pin", pin,
                "nomBoutiqueMarche", "Grand Dépôt Mandé")), 201);
        assertEquals("EN_ATTENTE", inscrit.get("statut").asText());
        String code = inscrit.get("codeOtp").asText();   // profil demo : le code est renvoyé

        assertEquals("EN_ATTENTE", json(post("/api/auth/verifier-otp", null,
                Map.of("telephone", telephone, "code", code)), 200).get("statut").asText());

        // --- connexion : un compte en attente de KYC peut se connecter pour déposer son dossier
        JsonNode connexion = json(post("/api/auth/connexion", null, Map.of("telephone", telephone, "pin", pin)), 200);
        String jeton = connexion.get("jeton").asText();
        assertEquals("EN_ATTENTE", connexion.get("profil").get("statut").asText());
        appel(MockMvcRequestBuilders.get("/api/kyc/moi"), jeton, 404);

        // --- un dossier incomplet est refusé (RG-04 : NIF manquant)
        appel(kyc(List.of("PIECE_IDENTITE", "REGISTRE_COMMERCE"), List.of(PNG, PDF)), jeton, 400);

        // --- dépôt complet, avec les pièces facultatives de l'écran « Soumettre mes documents »
        JsonNode dossier = json(appel(kyc(List.of("PIECE_IDENTITE", "REGISTRE_COMMERCE", "NIF", "RELEVE_BANCAIRE", "AUTRE"),
                List.of(JPEG, PDF, PNG, PDF, PNG)), jeton, 201));
        assertEquals("EN_ATTENTE", dossier.get("statut").asText());
        assertEquals(5, dossier.get("documents").size());
        assertEquals("EN_ATTENTE", json(appel(MockMvcRequestBuilders.get("/api/kyc/moi"), jeton, 200)).get("statut").asText());

        // --- tant que le dossier n'est pas validé, le catalogue reste verrouillé
        appel(produit(null), jeton, 403);

        // --- un administrateur VALIDATION approuve le dossier (RG-05)
        String validation = json(post("/api/auth/connexion", null, Map.of("telephone", "+22370000002", "pin", "2580")), 200)
                .get("jeton").asText();
        json(post("/api/admin/kyc/" + dossier.get("id").asLong() + "/decision", validation,
                Map.of("decision", "APPROUVE", "commentaire", "Pièces conformes")), 200);

        // --- photo envoyée comme le fait Flutter (MultipartFile.fromBytes : application/octet-stream)
        MockMultipartFile photo = new MockMultipartFile("photo", "produit.png", "application/octet-stream", PNG);
        JsonNode upload = json(appel(MockMvcRequestBuilders.multipart("/api/catalogue/upload-photo").file(photo), jeton, 200));
        String photoUrl = upload.get("photoUrl").asText();
        assertTrue(photoUrl.startsWith("/api/public/images/produits/") && photoUrl.endsWith(".png"), photoUrl);
        appel(MockMvcRequestBuilders.get(photoUrl), null, 200);

        // un fichier qui n'est pas une image est refusé, quel que soit le type déclaré
        MockMultipartFile faux = new MockMultipartFile("photo", "x.png", "image/png", "pas une image".getBytes());
        appel(MockMvcRequestBuilders.multipart("/api/catalogue/upload-photo").file(faux), jeton, 400);

        // --- création du produit (corps identique à celui d'AjouterProduitScreen)
        long categorieId = json(appel(MockMvcRequestBuilders.get("/api/catalogue/categories"), null, 200)).get(0).get("id").asLong();
        JsonNode cree = json(appel(produit(Map.of(
                "categorieId", categorieId, "nom", "Sneakers Joyride", "description", "Semelle amortissante",
                "paysOrigine", "Chine", "photoUrl", photoUrl,
                "variantes", List.of(
                        Map.of("sku", "SKU-JOY-42", "taille", "42", "couleur", "Noir", "qteDisponible", 120),
                        Map.of("sku", "SKU-JOY-43", "taille", "43", "couleur", "Noir", "qteDisponible", 80)))),
                jeton, 201));
        assertEquals("Sneakers Joyride", cree.get("nom").asText());
        assertEquals(photoUrl, cree.get("photoUrl").asText());
        assertEquals(2, cree.get("variantes").size());

        JsonNode mesProduits = json(appel(MockMvcRequestBuilders.get("/api/catalogue/produits"), jeton, 200));
        assertTrue(mesProduits.findValues("id").stream().anyMatch(id -> id.asLong() == cree.get("id").asLong()));
    }

    // ------------------------------------------------------------------ outils

    private MockHttpServletRequestBuilder kyc(List<String> types, List<byte[]> fichiers) {
        var requete = MockMvcRequestBuilders.multipart("/api/kyc");
        for (int i = 0; i < types.size(); i++) {
            requete.file(new MockMultipartFile("fichiers", "piece" + i, "application/octet-stream", fichiers.get(i)));
        }
        // comme l'application mobile : une seule valeur, types séparés par des virgules
        requete.param("types", String.join(",", types));
        return requete;
    }

    private MockHttpServletRequestBuilder produit(Map<String, Object> corps) throws Exception {
        Map<String, Object> c = corps != null ? corps : Map.of("categorieId", 1, "nom", "x",
                "variantes", List.of(Map.of("sku", "S", "qteDisponible", 1)));
        return MockMvcRequestBuilders.post("/api/catalogue/produits")
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(c));
    }

    private MockHttpServletRequestBuilder post(String url, String jeton, Object corps) throws Exception {
        var requete = MockMvcRequestBuilders.post(url).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(corps));
        if (jeton != null) {
            requete.header("Authorization", "Bearer " + jeton);
        }
        return requete;
    }

    private JsonNode json(MockHttpServletRequestBuilder requete, int statutAttendu) throws Exception {
        return json(appel(requete, null, statutAttendu));
    }

    private MockHttpServletResponse appel(MockHttpServletRequestBuilder requete, String jeton, int statutAttendu)
            throws Exception {
        if (jeton != null) {
            requete.header("Authorization", "Bearer " + jeton);
        }
        MockHttpServletResponse reponse = mvc.perform(requete).andReturn().getResponse();
        assertEquals(statutAttendu, reponse.getStatus(), reponse.getContentAsString());
        return reponse;
    }

    private JsonNode json(MockHttpServletResponse reponse) throws Exception {
        String texte = reponse.getContentAsString();
        return texte.isBlank() ? json.createObjectNode() : json.readTree(texte);
    }
}
