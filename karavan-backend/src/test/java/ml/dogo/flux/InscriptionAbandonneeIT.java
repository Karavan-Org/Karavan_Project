package ml.dogo.flux;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/**
 * RG-01 / RG-02 : une inscription interrompue avant la saisie du code (ou faite avec le numéro d'un autre)
 * ne bloque pas le numéro ; seul un numéro prouvé par OTP est réservé.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:mysql://localhost:3306/karavan_test?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&createDatabaseIfNotExist=true",
        "spring.flyway.clean-disabled=false"})
@AutoConfigureMockMvc
@ActiveProfiles("demo")
@Import(FluxPrincipalIT.BaseVierge.class)
class InscriptionAbandonneeIT {

    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;

    @Test
    void uneInscriptionNonFinaliseeEstRemplaceeEtLeNumeroReserveUneFoisProuve() throws Exception {
        String telephone = "+22378" + (100_000 + (System.nanoTime() % 900_000));

        // Quelqu'un crée un compte Grossiste sur ce numéro puis s'arrête avant le code
        inscrire(telephone, "GROSSISTE", 201);

        // Tant que le numéro n'est pas prouvé, une nouvelle inscription remplace aussitôt la précédente,
        // d'un autre type au besoin (règle assouplie le 27/10, commit d36f8ff)
        JsonNode nouveau = inscrire(telephone, "COMMERCANT", 201);
        assertEquals("EN_ATTENTE", nouveau.get("statut").asText());

        // Le code de la dernière inscription prouve le numéro : le compte Commerçant est actif
        appel("/api/auth/verifier-otp", Map.of("telephone", telephone, "code", nouveau.get("codeOtp").asText()), 200);
        JsonNode connexion = json.readTree(appel("/api/auth/connexion",
                Map.of("telephone", telephone, "pin", "4826"), 200).getContentAsString());
        assertEquals("COMMERCANT", connexion.get("profil").get("type").asText());

        // Désormais vérifié, le numéro est réservé
        assertEquals("CONFLIT", inscrire(telephone, "GROSSISTE", 409).get("code").asText());
    }

    @Test
    void unNumeroVerifieResteReserve() throws Exception {
        // Compte de démonstration au téléphone vérifié : jamais remplaçable par une nouvelle inscription
        assertEquals("CONFLIT", inscrire("+22373000001", "GROSSISTE", 409).get("code").asText());
    }

    private JsonNode inscrire(String telephone, String type, int statut) throws Exception {
        Map<String, Object> corps = "GROSSISTE".equals(type)
                ? Map.of("type", type, "telephone", telephone, "nom", "Essai", "pin", "4826", "nomBoutiqueMarche", "Dépôt")
                : Map.of("type", type, "telephone", telephone, "nom", "Essai", "pin", "4826", "nomBoutique", "Boutique");
        return json.readTree(appel("/api/auth/inscription", corps, statut).getContentAsString());
    }

    private MockHttpServletResponse appel(String url, Object corps, int statut) throws Exception {
        MockHttpServletResponse r = mvc.perform(MockMvcRequestBuilders.post(url).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(corps))).andReturn().getResponse();
        assertEquals(statut, r.getStatus(), r.getContentAsString());
        return r;
    }
}
