package ml.dogo.identite;

import ml.dogo.identite.application.Auth0AuthService;
import ml.dogo.identite.application.Auth0TokenVerifier;
import ml.dogo.identite.application.Auth0UserInfo;
import ml.dogo.identite.application.JetonInscriptionTemporaireService;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.TypeActeur;
import ml.dogo.identite.persistence.CompteExterne;
import ml.dogo.identite.persistence.CompteExterneRepository;
import ml.dogo.identite.persistence.Role;
import ml.dogo.identite.persistence.RoleRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:mysql://localhost:3306/karavan_test?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&createDatabaseIfNotExist=true",
        "spring.flyway.clean-disabled=false",
        "dogo.otp.afficher-dans-reponse=true"
})
@ActiveProfiles("demo")
@Transactional
public class Auth0AuthTest {

    @Autowired
    private Auth0AuthService auth0AuthService;

    @Autowired
    private Auth0TokenVerifier auth0TokenVerifier;

    @Autowired
    private UtilisateurRepository utilisateurs;

    @Autowired
    private CompteExterneRepository comptesExternes;

    @Test
    @DisplayName("Le mock Auth0 extrait correctement les claims de test")
    void testMockVerifier() {
        Auth0UserInfo info = auth0TokenVerifier.verifier("mock-auth0-token:auth0|salif-123:salif@karavan.ml:true:Salif Keita:");
        assertThat(info.sub()).isEqualTo("auth0|salif-123");
        assertThat(info.email()).isEqualTo("salif@karavan.ml");
        assertThat(info.emailVerified()).isTrue();
        assertThat(info.nom()).isEqualTo("Salif Keita");
    }

    @Test
    @DisplayName("Un nouveau compte Auth0 renvoie PROFIL_INCOMPLET avec un jeton d'inscription")
    void testNouveauCompteProfilIncomplet() {
        var res = auth0AuthService.authentifier("mock-auth0-token:auth0|nouveau-456:nouveau@karavan.ml:true:Nouveau Client:", "dev-1", "127.0.0.1");
        assertThat(res.statut()).isEqualTo("PROFIL_INCOMPLET");
        assertThat(res.jetonInscription()).isNotNull().isNotBlank();
        assertThat(res.sub()).isEqualTo("auth0|nouveau-456");
    }
}

