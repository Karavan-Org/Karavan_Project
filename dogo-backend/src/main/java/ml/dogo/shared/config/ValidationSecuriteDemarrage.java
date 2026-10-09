package ml.dogo.shared.config;

import java.util.Arrays;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/**
 * Vérifie au démarrage de l'application que les secrets cryptographiques critiques ne sont pas
 * ceux fournis par défaut dans les dépôts de code en environnement de production (RG-06, RG-58).
 */
@Component
public class ValidationSecuriteDemarrage implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(ValidationSecuriteDemarrage.class);

    private static final List<String> SECRETS_INTERDITS = List.of(
            "dogo-secret-jwt-a-changer-absolument-en-production-min-256-bits-ok!",
            "dogo-hmac-secret-orange-money-moov-min-256-bits-ok!",
            "changez-moi-changez-moi-changez-moi-32-octets-minimum",
            "secret-de-demo-a-remplacer",
            "secret",
            "password",
            "123456"
    );

    private final DogoProperties proprietes;
    private final Environment environment;

    public ValidationSecuriteDemarrage(DogoProperties proprietes, Environment environment) {
        this.proprietes = proprietes;
        this.environment = environment;
    }

    @Override
    public void run(ApplicationArguments args) {
        boolean estProduction = Arrays.asList(environment.getActiveProfiles()).contains("prod");
        String jwtSecret = proprietes.jwt() != null ? proprietes.jwt().secret() : "";
        String hmacSecret = proprietes.mobileMoney() != null ? proprietes.mobileMoney().secretCallback() : "";

        if (estProduction) {
            if (Arrays.asList(environment.getActiveProfiles()).contains("demo")) {
                throw new IllegalStateException("Le profil 'demo' ne peut pas être activé avec le profil 'prod'.");
            }
            String dbUser = environment.getProperty("spring.datasource.username", "");
            String dbPassword = environment.getProperty("spring.datasource.password", "");
            if ("root".equalsIgnoreCase(dbUser) || dbPassword == null || dbPassword.isBlank()
                    || "1234".equals(dbPassword)) {
                throw new IllegalStateException("SÉCURITÉ CRITIQUE : configurez un compte et mot de passe DB dédiés en profil 'prod'.");
            }
            if (jwtSecret == null || jwtSecret.length() < 32 || SECRETS_INTERDITS.contains(jwtSecret)) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : dogo.jwt.secret par défaut ou trop faible détecté en profil 'prod' ! "
                                + "Définissez la variable d'environnement DOGO_JWT_SECRET.");
            }
            if (hmacSecret == null || hmacSecret.length() < 32 || SECRETS_INTERDITS.contains(hmacSecret)) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : dogo.mobile-money.secret-callback par défaut ou trop faible détecté en profil 'prod' ! "
                                + "Définissez la variable d'environnement DOGO_MM_SECRET.");
            }
            if (proprietes.otp() != null && proprietes.otp().afficherDansReponse()) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : dogo.otp.afficher-dans-reponse ne doit JAMAIS être activé en profil 'prod' !");
            }
        } else {
            if (SECRETS_INTERDITS.contains(jwtSecret)) {
                log.warn("ATTENTION SÉCURITÉ : dogo.jwt.secret utilise la valeur par défaut pour l'environnement non-production.");
            }
            if (SECRETS_INTERDITS.contains(hmacSecret)) {
                log.warn("ATTENTION SÉCURITÉ : dogo.mobile-money.secret-callback utilise la valeur par défaut pour l'environnement non-production.");
            }
        }
    }
}
