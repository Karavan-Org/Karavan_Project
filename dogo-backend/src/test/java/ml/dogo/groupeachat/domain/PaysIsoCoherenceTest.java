package ml.dogo.groupeachat.domain;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

/**
 * Règle de cohérence stricte : aucun code ISO orphelin entre la table `pays` et les données du globe.
 */
class PaysIsoCoherenceTest {

    private static final List<String> CODES_PAYS_PLATEFORME = List.of(
            "ML", "CN", "TR", "AE", "IN", "FR", "MA", "SN", "CI", "GH",
            "NG", "TG", "BJ", "ES", "DE", "IT", "US", "BR", "VN", "TH",
            "SA", "EG", "ZA"
    );

    @Test
    void tousLesCodesPaysDeLaPlateformeExistentDansLeGeoJsonDuGlobe() throws Exception {
        // Le fichier GeoJSON est embarqué localement dans le module Angular pour le globe 3D
        Path cheminGeoJson = Paths.get("../dogo-angular/src/assets/geo/ne_110m_admin_0_countries.geojson");
        if (!Files.exists(cheminGeoJson)) {
            cheminGeoJson = Paths.get("dogo-angular/src/assets/geo/ne_110m_admin_0_countries.geojson");
        }
        assertTrue(Files.exists(cheminGeoJson), "Le fichier GeoJSON du globe doit exister localement");

        String contenu = Files.readString(cheminGeoJson, StandardCharsets.UTF_8);
        assertFalse(contenu.isBlank());

        for (String codeIso : CODES_PAYS_PLATEFORME) {
            boolean present = contenu.contains("\"ISO_A2\":\"" + codeIso + "\"")
                    || contenu.contains("\"ISO_A2\": \"" + codeIso + "\"")
                    || contenu.contains("\"" + codeIso + "\"");
            assertTrue(present, "Le code ISO " + codeIso + " doit être présent dans le GeoJSON du globe");
        }
    }
}
