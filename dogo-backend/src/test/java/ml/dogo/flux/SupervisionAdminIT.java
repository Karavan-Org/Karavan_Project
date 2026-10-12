package ml.dogo.flux;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.stream.StreamSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/**
 * Console d'administration (dogo-angular) : chaque rôle administratif consulte les comptes, seul le rôle TECHNIQUE
 * voit et crée les administrateurs, et la fiche d'un acteur peut relire tout son historique KYC.
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
class SupervisionAdminIT {

    private static final String PIN = "2580";

    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;

    @Test
    void chaqueRoleAdministratifConsulteCeQuiLuiRevient() throws Exception {
        String technique = connexion("+22370000001");
        String finance = connexion("+22370000003");
        String support = connexion("+22370000004");

        // --- finance et support consultent les comptes (litiges, retraits) ainsi que les groupes
        for (String jeton : new String[] {finance, support}) {
            JsonNode commercants = get("/api/admin/commercants", jeton, 200);
            assertTrue(commercants.size() > 0);
            assertTrue(commercants.get(0).has("dateCreation"));
            get("/api/admin/grossistes", jeton, 200);
            get("/api/admin/courtiers", jeton, 200);
        }
        get("/api/admin/groupes", finance, 200);

        // --- seul le rôle TECHNIQUE liste les administrateurs
        get("/api/admin/administrateurs", finance, 403);
        JsonNode admins = get("/api/admin/administrateurs", technique, 200);
        assertEquals(4, StreamSupport.stream(admins.spliterator(), false)
                .filter(a -> a.get("matricule").asText().startsWith("ADM-000")).count());

        // --- un administrateur créé par le rôle TECHNIQUE apparaît aussitôt dans l'équipe
        String telephone = "+22378" + (100_000 + (System.nanoTime() % 900_000));
        appel(post("/api/admin/administrateurs", Map.of("telephone", telephone, "nom", "Agent Support",
                "pin", "1357", "matricule", "ADM-" + telephone.substring(6), "role", "SUPPORT")), technique, 201);
        assertTrue(StreamSupport.stream(get("/api/admin/administrateurs", technique, 200).spliterator(), false)
                .anyMatch(a -> a.get("roleAdministratif").asText().equals("SUPPORT")
                        && a.get("nom").asText().equals("Agent Support")));

        // --- historique KYC d'un grossiste (fiche utilisateur) : réservé aux rôles qui gèrent les comptes
        long grossiste = get("/api/admin/grossistes", technique, 200).get(0).get("id").asLong();
        get("/api/admin/kyc/utilisateurs/" + grossiste, technique, 200);
        get("/api/admin/kyc/utilisateurs/" + grossiste, finance, 403);

        // --- les séquestres portent les identifiants des acteurs (liens de la fiche)
        JsonNode tableau = get("/api/admin/finance/sequestres", finance, 200);
        for (JsonNode s : tableau.get("sequestres")) {
            assertTrue(s.has("acheteurId") && s.has("beneficiaireId") && s.has("grossisteId") && s.has("courtierId"));
        }
    }

    @Test
    void leSuperAdministrateurAccepteUnCourtierEtReactiveUnCompteSuspendu() throws Exception {
        String technique = connexion("+22370000001");

        // --- un courtier inscrit depuis l'application, sans dossier KYC : il attend d'être accepté
        String telephone = "+22377" + (100_000 + (System.nanoTime() % 900_000));
        JsonNode inscrit = json(appel(post("/api/auth/inscription", Map.of("type", "COURTIER", "telephone", telephone,
                "nom", "Courtier Sans Dossier", "pin", "4826", "nomSocieteImport", "Niger Transit")), null, 201));
        long courtier = StreamSupport.stream(get("/api/admin/courtiers", technique, 200).spliterator(), false)
                .filter(c -> c.get("telephone").asText().equals(telephone)).findFirst().orElseThrow().get("id").asLong();
        appel(post("/api/auth/verifier-otp", Map.of("telephone", telephone, "code", inscrit.get("codeOtp").asText())), null, 200);
        assertEquals(0, get("/api/admin/kyc/utilisateurs/" + courtier, technique, 200).size());

        // --- le rôle TECHNIQUE l'accepte (validation manuelle, motif obligatoire)
        appel(post("/api/admin/kyc/utilisateurs/" + courtier + "/validation", Map.of("commentaire", " ")), technique, 400);
        JsonNode dossier = json(appel(post("/api/admin/kyc/utilisateurs/" + courtier + "/validation",
                Map.of("commentaire", "Licence de transit vérifiée au bureau")), technique, 200));
        assertEquals("APPROUVE", dossier.get("statut").asText());
        assertEquals("ACTIF", statutDe(courtier, technique));

        // --- un compte de démo actif sans dossier : suspendu, il ne se réactive qu'après validation (RG-03)
        long grossisteDemo = StreamSupport.stream(get("/api/admin/grossistes", technique, 200).spliterator(), false)
                .filter(g -> g.get("telephone").asText().equals("+22371000001")).findFirst().orElseThrow()
                .get("id").asLong();
        appel(post("/api/admin/comptes/" + grossisteDemo + "/suspension", Map.of("motif", "Contrôle")), technique, 204);
        appel(post("/api/admin/comptes/" + grossisteDemo + "/reactivation", Map.of()), technique, 409);
        json(appel(post("/api/admin/kyc/utilisateurs/" + grossisteDemo + "/validation",
                Map.of("commentaire", "NIF et RCCM vérifiés")), technique, 200));
        assertEquals("SUSPENDU", statutDe(grossisteDemo, technique));   // la validation ne lève pas la suspension
        appel(post("/api/admin/comptes/" + grossisteDemo + "/reactivation", Map.of()), technique, 204);
        assertEquals("ACTIF", statutDe(grossisteDemo, technique));
    }

    private String statutDe(long id, String jeton) throws Exception {
        for (String liste : new String[] {"/api/admin/grossistes", "/api/admin/courtiers"}) {
            for (JsonNode c : get(liste, jeton, 200)) {
                if (c.get("id").asLong() == id) {
                    return c.get("statut").asText();
                }
            }
        }
        throw new AssertionError("compte introuvable : " + id);
    }

    // ------------------------------------------------------------------ utilitaires

    private String connexion(String telephone) throws Exception {
        return json(appel(post("/api/auth/connexion", Map.of("telephone", telephone, "pin", PIN)), null, 200))
                .get("jeton").asText();
    }

    private JsonNode get(String url, String jeton, int statutAttendu) throws Exception {
        return json(appel(MockMvcRequestBuilders.get(url), jeton, statutAttendu));
    }

    private MockHttpServletRequestBuilder post(String url, Object corps) throws Exception {
        return MockMvcRequestBuilders.post(url).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(corps));
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
