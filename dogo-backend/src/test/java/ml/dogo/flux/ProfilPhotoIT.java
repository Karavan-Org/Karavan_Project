package ml.dogo.flux;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
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
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:mysql://localhost:3306/dogo_test?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&createDatabaseIfNotExist=true",
        "spring.flyway.clean-disabled=false",
        "dogo.retrait.max-tentatives=3"})
@AutoConfigureMockMvc
@ActiveProfiles("demo")
@Import(FluxPrincipalIT.BaseVierge.class)
class ProfilPhotoIT {

    private static final String MOT_DE_PASSE = "Dogo2026!";
    private static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0x10, 'J', 'F', 'I', 'F'};

    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;

    @Test
    void personnalisationPhotoProfilParActeurEtVisibiliteAdmin() throws Exception {
        // 1. Connexion du commerçant de démo
        String jetonCommercant = connexion("+22373000001", MOT_DE_PASSE);

        // 2. Upload de photo de profil
        MockMultipartFile photo = new MockMultipartFile("photo", "mon_avatar.jpg", "image/jpeg", JPEG);
        MockHttpServletResponse reponseUpload = appel(
                MockMvcRequestBuilders.multipart("/api/moi/photo").file(photo),
                jetonCommercant,
                200
        );
        JsonNode uploadJson = json(reponseUpload);
        assertTrue(uploadJson.has("photoUrl"));
        String photoUrl = uploadJson.get("photoUrl").asText();
        assertTrue(photoUrl.startsWith("/api/public/images/avatars/avatar_"));

        // 3. Consultation du profil par le commerçant : photo présente
        JsonNode profilMoi = get("/api/moi", jetonCommercant, 200);
        assertEquals(photoUrl, profilMoi.get("photoUrl").asText());

        // 4. Consultation par l'administrateur : photo visible dans la liste des commerçants
        String jetonAdmin = connexion("+22370000001", MOT_DE_PASSE);
        JsonNode commercants = get("/api/admin/commercants", jetonAdmin, 200);
        assertTrue(commercants.size() > 0);
        JsonNode monCompteAdmin = StreamSupport.stream(commercants.spliterator(), false)
                .filter(c -> c.get("telephone").asText().equals("+22373000001"))
                .findFirst()
                .orElse(null);
        assertNotNull(monCompteAdmin);
        assertEquals(photoUrl, monCompteAdmin.get("photoUrl").asText());

        // 5. Test rejet fichier invalide (non-image)
        MockMultipartFile fauxFichier = new MockMultipartFile("photo", "malveillant.exe", "application/octet-stream",
                "non-image-content".getBytes());
        appel(MockMvcRequestBuilders.multipart("/api/moi/photo").file(fauxFichier), jetonCommercant, 400);
    }

    private String connexion(String telephone, String pin) throws Exception {
        MockHttpServletResponse res = appel(
                MockMvcRequestBuilders.post("/api/auth/connexion")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("telephone", telephone, "pin", pin))),
                null,
                200
        );
        return json(res).get("jeton").asText();
    }

    private JsonNode get(String url, String jeton, int statutAttendu) throws Exception {
        return json(appel(MockMvcRequestBuilders.get(url), jeton, statutAttendu));
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
