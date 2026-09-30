package ml.dogo.shared.config;

import java.math.BigDecimal;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** Paramètres métier et techniques, tous configurables dans application.yml (préfixe « dogo »). */
@ConfigurationProperties(prefix = "dogo")
public record DogoProperties(Jwt jwt, Otp otp, Pin pin, Session session, Reservation reservation,
                             Commission commission, Retrait retrait, MobileMoney mobileMoney, Stockage stockage) {

    public record Jwt(String secret) {
    }

    /** RG-02. */
    public record Otp(Duration validite, int maxTentatives, boolean afficherDansReponse) {
    }

    /** RG-07. */
    public record Pin(int maxEchecs, Duration verrouillage) {
    }

    /** RG-08. */
    public record Session(Duration inactivite) {
    }

    /** RG-28. */
    public record Reservation(Duration duree) {
    }

    /** RG-37. */
    public record Commission(BigDecimal taux) {
    }

    /** RG-54. */
    public record Retrait(Duration validite, int maxTentatives) {
    }

    public record MobileMoney(String secretCallback) {
    }

    public record Stockage(String dossier) {
    }
}
