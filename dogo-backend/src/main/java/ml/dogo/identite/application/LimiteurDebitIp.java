package ml.dogo.identite.application;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Component;

/**
 * Limiteur de requêtes par adresse IP pour protéger les endpoints d'authentification externe
 * contre les abus et les attaques par déni de service.
 */
@Component
public class LimiteurDebitIp {

    private static final int MAX_REQUETES_PAR_MINUTE = 20;
    private static final Duration FENETRE = Duration.ofMinutes(1);

    private record CompteurFenetre(Instant debut, AtomicInteger compteur) {}

    private final ConcurrentHashMap<String, CompteurFenetre> compteursParIp = new ConcurrentHashMap<>();

    /**
     * Vérifie et incrémente le compteur pour l'IP donnée.
     *
     * @param ip adresse IP du client
     * @throws ErreurMetier si le quota de requêtes par minute est dépassé
     */
    public void verifierLimite(String ip) {
        if (ip == null || ip.isBlank() || "127.0.0.1".equals(ip) || "0:0:0:0:0:0:0:1".equals(ip)) {
            // Localhost ne bloque pas les développeurs locaux
            return;
        }

        Instant maintenant = Instant.now();
        compteursParIp.compute(ip, (cle, existant) -> {
            if (existant == null || maintenant.isAfter(existant.debut().plus(FENETRE))) {
                return new CompteurFenetre(maintenant, new AtomicInteger(1));
            }
            if (existant.compteur().incrementAndGet() > MAX_REQUETES_PAR_MINUTE) {
                throw new ErreurMetier(CodeErreur.QUOTA_INSUFFISANT, "RG-07",
                        "Trop de tentatives d'authentification depuis cette adresse IP. Veuillez patienter une minute.");
            }
            return existant;
        });
    }
}

