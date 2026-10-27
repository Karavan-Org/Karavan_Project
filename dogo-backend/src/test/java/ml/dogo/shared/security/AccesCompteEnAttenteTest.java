package ml.dogo.shared.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

class AccesCompteEnAttenteTest {

    private static boolean autorise(String methode, String chemin) {
        return AccesCompteEnAttente.autorise(new MockHttpServletRequest(methode, chemin));
    }

    @Test
    void leParcoursDeVerificationResteOuvert() {
        assertThat(autorise("POST", "/api/kyc")).isTrue();
        assertThat(autorise("GET", "/api/kyc/moi")).isTrue();
        assertThat(autorise("GET", "/api/moi")).isTrue();
        assertThat(autorise("POST", "/api/moi/mot-de-passe")).isTrue();
        assertThat(autorise("POST", "/api/moi/deconnexion")).isTrue();
        assertThat(autorise("GET", "/api/moi/notifications")).isTrue();
        assertThat(autorise("POST", "/api/moi/notifications/12/lue")).isTrue();
        assertThat(autorise("POST", "/api/auth/refresh")).isTrue();
        assertThat(autorise("OPTIONS", "/api/catalogue/produits")).isTrue();
    }

    @Test
    void touteAutreActionEstRefusee() {
        assertThat(autorise("POST", "/api/catalogue/produits")).isFalse();
        assertThat(autorise("POST", "/api/catalogue/upload-photo")).isFalse();
        assertThat(autorise("GET", "/api/catalogue/produits")).isFalse();
        assertThat(autorise("PATCH", "/api/moi")).isFalse();
        assertThat(autorise("POST", "/api/moi/moyens-paiement")).isFalse();
        assertThat(autorise("GET", "/api/moi/portefeuille")).isFalse();
        assertThat(autorise("POST", "/api/groupes")).isFalse();
        assertThat(autorise("GET", "/api/admin/kyc")).isFalse();
        // Pas de contournement par un chemin voisin
        assertThat(autorise("POST", "/api/kyc/moi")).isFalse();
        assertThat(autorise("GET", "/api/moi/notifications/../portefeuille")).isFalse();
    }
}
