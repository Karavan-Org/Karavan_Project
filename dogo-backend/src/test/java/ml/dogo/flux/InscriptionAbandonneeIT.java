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
 * ne bloque pas le numéro, sans pour autant permettre de détourner une inscription en cours.
 * Codes valables 1 seconde ici pour simuler l'abandon ; le test attend le délai de 30 s entre deux SMS.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:mysql://localhost:3306/dogo_test?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&createDatabaseIfNotExist=true",
        "spring.flyway.clean-disabled=false",
        "dogo.otp.validite=PT1S"})
@AutoConfigureMockMvc
@ActiveProfiles("demo")
@Import(FluxPrincipalIT.BaseVierge.class)
class InscriptionAbandonneeIT {

    @Autowired
    private MockMvc mvc;
    @Autowired
    private ObjectMapper json;

    @Test
    void uneInscriptionAbandonneeEstRemplaceeMaisPasUneInscriptionEnCours() throws Exception {
        String telephone = "+22378" + (100_000 + (System.nanoTime() % 900_000));

        // Quelqu'un crée un compte Grossiste sur ce numéro puis abandonne avant le code
        inscrire(telephone, "GROSSISTE", 201);

        // Pendant que le code est valable, l'inscription en cours est protégée
        assertEquals("CONFLIT", inscrire(telephone, "COMMERCANT", 409).get("code").asText());

        // Le code expire (et le délai de 30 s entre deux SMS au même numéro est écoulé) : le numéro, jamais prouvé,
        // est libéré pour une nouvelle inscription, d'un autre type au besoin
        Thread.sleep(31_000);
        JsonNode nouveau = inscrire(telephone, "COMMERCANT", 201);
        assertEquals("EN_ATTENTE", nouveau.get("statut").asText());

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
