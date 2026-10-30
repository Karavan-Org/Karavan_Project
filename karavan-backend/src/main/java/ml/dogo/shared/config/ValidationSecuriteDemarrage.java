package ml.dogo.shared.config;

import java.util.Arrays;
import java.util.List;
import java.net.URI;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Component;

/**
 * Vérifie au démarrage de l'application que les secrets cryptographiques critiques ne sont pas
 * ceux fournis par défaut dans les dépôts de code en environnement de production (RG-06, RG-58).
 */
@Component
public class ValidationSecuriteDemarrage implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(ValidationSecuriteDemarrage.class);
    private static final String HACHAGE_MOT_DE_PASSE_PARTAGE =
            "$2a$10$VNiROclYlckAH4ERMjsfsePZ0DHctlkdy684DEdkFhEu8R4Lli.xq";
    private static final Pattern MINUSCULE = Pattern.compile("[a-z]");
    private static final Pattern MAJUSCULE = Pattern.compile("[A-Z]");
    private static final Pattern CHIFFRE = Pattern.compile("[0-9]");
    private static final Pattern SPECIAL = Pattern.compile("[^A-Za-z0-9]");

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
    private final JdbcTemplate jdbc;

    public ValidationSecuriteDemarrage(DogoProperties proprietes, Environment environment, JdbcTemplate jdbc) {
        this.proprietes = proprietes;
        this.environment = environment;
        this.jdbc = jdbc;
    }

    @Override
    public void run(ApplicationArguments args) {
        boolean estProduction = environment.acceptsProfiles(Profiles.of("prod"));
        String jwtSecret = proprietes.jwt() != null ? proprietes.jwt().secret() : "";
        String hmacSecret = proprietes.mobileMoney() != null ? proprietes.mobileMoney().secretCallback() : "";

        if (estProduction) {
            if (environment.acceptsProfiles(Profiles.of("demo"))) {
                throw new IllegalStateException("Le profil 'demo' ne peut pas être activé avec le profil 'prod'.");
            }
            String dbUser = environment.getProperty("spring.datasource.username", "");
            String dbPassword = environment.getProperty("spring.datasource.password", "");
            boolean autoriserRoot = Boolean.parseBoolean(environment.getProperty("DOGO_ALLOW_ROOT_DB", "false"))
                    || environment.containsProperty("RAILWAY_ENVIRONMENT")
                    || environment.containsProperty("RENDER");
            if ((!autoriserRoot && "root".equalsIgnoreCase(dbUser)) || dbPassword == null || dbPassword.length() < 8
                    || "1234".equals(dbPassword)) {
                throw new IllegalStateException("SÉCURITÉ CRITIQUE : configurez un compte et mot de passe DB dédiés en profil 'prod'.");
            }
            if (!secretRobuste(jwtSecret)) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : dogo.jwt.secret par défaut ou trop faible détecté en profil 'prod' ! "
                                + "Définissez la variable d'environnement DOGO_JWT_SECRET.");
            }
            if (!secretRobuste(hmacSecret)) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : dogo.mobile-money.secret-callback par défaut ou trop faible détecté en profil 'prod' ! "
                                + "Définissez la variable d'environnement DOGO_MM_SECRET.");
            }
            if (proprietes.otp() != null && proprietes.otp().afficherDansReponse()) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : dogo.otp.afficher-dans-reponse ne doit JAMAIS être activé en profil 'prod' !");
            }
            if (!Boolean.parseBoolean(environment.getProperty("dogo.auth.cookie-secure", "false"))) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : activez DOGO_COOKIE_SECURE=true pour les cookies de session en production.");
            }
            if (!originesCorsProductionValides()) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : DOGO_CORS_ORIGINS doit contenir uniquement des origines HTTPS exactes, sans joker.");
            }
            Integer comptesAvecMotDePassePartage = jdbc.queryForObject(
                    "select count(*) from utilisateur where mot_de_passe_hash = ?",
                    Integer.class, HACHAGE_MOT_DE_PASSE_PARTAGE);
            if (comptesAvecMotDePassePartage != null && comptesAvecMotDePassePartage > 0) {
                throw new IllegalStateException(
                        "SÉCURITÉ CRITIQUE : " + comptesAvecMotDePassePartage
                                + " compte(s) utilisent encore le mot de passe partagé de la migration V11. "
                                + "Réinitialisez ces comptes avant de démarrer en production.");
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

    private static boolean secretRobuste(String secret) {
        if (secret == null || secret.length() < 32 || SECRETS_INTERDITS.contains(secret)
                || secret.chars().distinct().count() < 12) {
            return false;
        }
        int categories = 0;
        if (MINUSCULE.matcher(secret).find()) categories++;
        if (MAJUSCULE.matcher(secret).find()) categories++;
        if (CHIFFRE.matcher(secret).find()) categories++;
        if (SPECIAL.matcher(secret).find()) categories++;
        return categories >= 3;
    }

    private boolean originesCorsProductionValides() {
        String origines = environment.getProperty("dogo.cors.origines", "");
        if (origines.isBlank()) return false;
        return Arrays.stream(origines.split(",")).map(String::trim).allMatch(origine -> {
            try {
                URI uri = URI.create(origine);
                return "https".equalsIgnoreCase(uri.getScheme()) && uri.getHost() != null
                        && (uri.getRawPath() == null || uri.getRawPath().isEmpty() || "/".equals(uri.getRawPath()))
                        && uri.getRawQuery() == null && uri.getRawUserInfo() == null
                        && !origine.contains("*");
            } catch (IllegalArgumentException invalide) {
                return false;
            }
        });
    }
}
