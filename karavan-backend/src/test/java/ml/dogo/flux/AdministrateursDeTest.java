package ml.dogo.flux;

import ml.dogo.identite.application.AdministrateurService;
import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.persistence.UtilisateurRepository;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.ApplicationListener;
import org.springframework.context.annotation.Bean;

/**
 * Administrateurs propres aux tests d'intégration : depuis V26 la base ne contient que l'administrateur principal
 * (mot de passe provisoire, donc bloqué tant qu'il n'est pas changé). Un compte par fonction, mot de passe définitif.
 */
@TestConfiguration
public class AdministrateursDeTest {

    static final String MOT_DE_PASSE = "Dogo2026!";

    @Bean
    ApplicationListener<ApplicationReadyEvent> creerAdministrateursDeTest(AdministrateurService administrateurs,
                                                                          UtilisateurRepository utilisateurs) {
        return evenement -> {
            creer(administrateurs, utilisateurs, "+22370000001", "Admin Technique", "ADM-T001", RoleAdministratif.TECHNIQUE);
            creer(administrateurs, utilisateurs, "+22370000002", "Admin Validation", "ADM-T002", RoleAdministratif.VALIDATION);
            creer(administrateurs, utilisateurs, "+22370000003", "Admin Finance", "ADM-T003", RoleAdministratif.FINANCE);
            creer(administrateurs, utilisateurs, "+22370000004", "Admin Support", "ADM-T004", RoleAdministratif.SUPPORT);
            creer(administrateurs, utilisateurs, "+22370000005", "Admin Logistique", "ADM-T005", RoleAdministratif.LOGISTIQUE);
        };
    }

    private static void creer(AdministrateurService administrateurs, UtilisateurRepository utilisateurs,
                              String telephone, String nom, String matricule, RoleAdministratif role) {
        if (!utilisateurs.existsByTelephone(telephone)) {
            administrateurs.creerInitial(telephone, nom, MOT_DE_PASSE, matricule, role);
        }
    }
}
