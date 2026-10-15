package ml.dogo.logistique;

import static org.assertj.core.api.Assertions.assertThat;

import ml.dogo.logistique.application.LocalisationService;
import org.junit.jupiter.api.Test;

class LocalisationServiceTest {

    @Test
    void lit_le_parametre_q() {
        var c = LocalisationService.depuisLien("https://maps.google.com/?q=12.6174,-7.9942").orElseThrow();
        assertThat(c.latitude()).isEqualTo(12.6174);
        assertThat(c.longitude()).isEqualTo(-7.9942);
    }

    @Test
    void prefere_l_epingle_du_lieu_au_centre_de_la_vue() {
        var c = LocalisationService.depuisLien("https://www.google.com/maps/place/Dabanani/@12.60,-8.00,17z/"
                + "data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d12.6391!4d-7.9978").orElseThrow();
        assertThat(c.latitude()).isEqualTo(12.6391);
        assertThat(c.longitude()).isEqualTo(-7.9978);
    }

    @Test
    void lit_le_centre_de_la_vue_et_les_coordonnees_encodees() {
        assertThat(LocalisationService.depuisLien("https://www.google.com/maps/@12.645,-7.995,15z")).isPresent();
        var c = LocalisationService.depuisLien("https://www.google.com/maps/search/?api=1&query=12.645%2C-7.995").orElseThrow();
        assertThat(c.longitude()).isEqualTo(-7.995);
        assertThat(LocalisationService.depuisLien("https://www.google.com/maps/search/12.645,+-7.995")).isPresent();
    }

    @Test
    void decode_le_plus_code_reel_du_depot() {
        var c = LocalisationService.depuisPlusCode("JXJF+76R, Unnamed Road, Bamako").orElseThrow();
        assertThat(c.latitude()).isCloseTo(12.6307375, org.assertj.core.data.Offset.offset(1e-7));
        assertThat(c.longitude()).isCloseTo(-8.0269844, org.assertj.core.data.Offset.offset(1e-7));
        // Vecteur officiel Open Location Code (decoding.csv)
        var officiel = LocalisationService.depuisPlusCode("7FG49QCJ+2VX").orElseThrow();
        assertThat(officiel.latitude()).isCloseTo(20.3701125, org.assertj.core.data.Offset.offset(1e-7));
        assertThat(officiel.longitude()).isCloseTo(2.782234375, org.assertj.core.data.Offset.offset(1e-7));
        assertThat(LocalisationService.depuisPlusCode("Rue 14, Porte 205")).isEmpty();
    }

    @Test
    void lien_court_ou_sans_coordonnees_non_lu_localement() {
        assertThat(LocalisationService.depuisLien("https://maps.app.goo.gl/AbCdEf123")).isEmpty();
        assertThat(LocalisationService.depuisLien("https://www.google.com/maps/place/Bamako")).isEmpty();
    }
}
