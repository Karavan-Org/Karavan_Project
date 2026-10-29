package ml.dogo.shared.config;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.boot.ApplicationArguments;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.env.MockEnvironment;

class ValidationSecuriteDemarrageTest {

    private static final String JWT = "Abcdef0123456789!@#$%^&*()_+-=XYZ";
    private static final String HMAC = "Qwerty9876543210!@#$%^&*()_+-=ABC";

    @Test
    void leProfilProductionParDefautExigeUneConfigurationSure() {
        MockEnvironment environment = environnementValide();
        environment.setActiveProfiles();
        environment.setDefaultProfiles("prod");
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Integer.class), any(Object[].class))).thenReturn(0);

        assertDoesNotThrow(() -> validateur(environment, jdbc).run(mock(ApplicationArguments.class)));
    }

    @Test
    void refuseLesOriginesCorsAvecJokerEnProduction() {
        MockEnvironment environment = environnementValide()
                .withProperty("dogo.cors.origines", "https://*.example.com");

        assertThrows(IllegalStateException.class,
                () -> validateur(environment, mock(JdbcTemplate.class)).run(mock(ApplicationArguments.class)));
    }

    @Test
    void refuseLeDemarrageSiLeMotDePassePartageDeV11EstEncoreUtilisable() {
        MockEnvironment environment = environnementValide();
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Integer.class), any(Object[].class))).thenReturn(2);

        assertThrows(IllegalStateException.class,
                () -> validateur(environment, jdbc).run(mock(ApplicationArguments.class)));
    }

    @Test
    void refuseLesSecretsLongsMaisFaibles() {
        MockEnvironment environment = environnementValide()
                .withProperty("dogo.jwt.secret", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");

        assertThrows(IllegalStateException.class,
                () -> validateur(environment, mock(JdbcTemplate.class)).run(mock(ApplicationArguments.class)));
    }

    private static ValidationSecuriteDemarrage validateur(MockEnvironment environment, JdbcTemplate jdbc) {
        DogoProperties properties = new DogoProperties(
                new DogoProperties.Jwt(environment.getProperty("dogo.jwt.secret")),
                new DogoProperties.Otp(Duration.ofMinutes(2), 3, false),
                new DogoProperties.Pin(5, Duration.ofMinutes(15)),
                new DogoProperties.Session(Duration.ofDays(30)),
                new DogoProperties.Reservation(Duration.ofMinutes(15)),
                new DogoProperties.Commission(new BigDecimal("0.05")),
                new DogoProperties.Retrait(Duration.ofDays(7), 3),
                new DogoProperties.MobileMoney(HMAC),
                new DogoProperties.Stockage("./uploads"));
        return new ValidationSecuriteDemarrage(properties, environment, jdbc);
    }

    private static MockEnvironment environnementValide() {
        MockEnvironment environment = new MockEnvironment()
                .withProperty("spring.datasource.username", "dogo_app")
                .withProperty("spring.datasource.password", "Db-secret-2026-very-strong")
                .withProperty("dogo.auth.cookie-secure", "true")
                .withProperty("dogo.cors.origines", "https://app.example.com,https://admin.example.com")
                .withProperty("dogo.jwt.secret", JWT)
                .withProperty("dogo.mobile-money.secret-callback", HMAC);
        environment.setActiveProfiles("prod");
        return environment;
    }
}
