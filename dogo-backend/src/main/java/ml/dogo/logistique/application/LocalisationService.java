package ml.dogo.logistique.application;

import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Coordonnées GPS d'un dépôt, pour afficher l'itinéraire dans l'application (carte intégrée) au lieu d'ouvrir
 * Google Maps. On lit d'abord les coordonnées contenues dans le lien Google Maps du point de retrait ; un lien
 * court (maps.app.goo.gl) est déroulé côté serveur, l'application web ne pouvant pas suivre ses redirections.
 * À défaut, l'adresse est géocodée via Nominatim (OpenStreetMap).
 */
@Service
public class LocalisationService {

    public record Coordonnees(double latitude, double longitude, String source) {
    }

    private static final Logger LOG = LoggerFactory.getLogger(LocalisationService.class);

    private static final String NOMBRE = "(-?\\d{1,3}(?:\\.\\d+)?)";
    /** Épingle exacte d'un lieu : {@code !3d<lat>!4d<lng>}. */
    private static final Pattern EPINGLE = Pattern.compile("!3d" + NOMBRE + "!4d" + NOMBRE);
    /** Paramètres porteurs de la destination : {@code q=}, {@code ll=}, {@code query=}, {@code destination=}… */
    private static final Pattern PARAMETRE = Pattern.compile(
            "[?&](?:q|ll|query|destination|daddr|center|sll)=(?:loc:)?\\s*" + NOMBRE + "\\s*,\\s*\\+?" + NOMBRE);
    /** Centre de la vue : {@code @<lat>,<lng>,<zoom>z}. */
    private static final Pattern VUE = Pattern.compile("@" + NOMBRE + "," + NOMBRE);
    /** Coordonnées dans le chemin : {@code /place/12.61,-7.99} ou {@code /search/12.61,+-7.99}. */
    private static final Pattern CHEMIN = Pattern.compile("/" + NOMBRE + "\\s*,\\s*\\+?" + NOMBRE + "(?:[/?&]|$)");
    /** Domaines Google autorisés pour le déroulé des redirections (pas de requête serveur vers un hôte arbitraire). */
    private static final Pattern HOTE_GOOGLE = Pattern.compile("^(?:[a-z0-9-]+\\.)*(?:google\\.[a-z.]{2,7}|goo\\.gl|g\\.co)$");
    private static final Pattern NOMINATIM = Pattern.compile("\"lat\"\\s*:\\s*\"" + NOMBRE + "\"\\s*,\\s*\"lon\"\\s*:\\s*\"" + NOMBRE + "\"");

    private static final String ALPHABET = "23456789CFGHJMPQRVWX";
    private static final double[] VALEURS_PAIRES = {20, 1, 0.05, 0.0025, 0.000125};
    private static final Pattern PLUS_CODE = Pattern.compile(
            "(?:^|[^0-9A-Z])([" + ALPHABET + "]{2,8})\\+([" + ALPHABET + "]{0,7})(?![0-9A-Z])");
    /** Référence pour compléter les Plus Codes courts : centre de Bamako. */
    private static final double BAMAKO_LAT = 12.6392;
    private static final double BAMAKO_LNG = -8.0029;

    private static final int REDIRECTIONS_MAX = 5;

    private final HttpClient http = HttpClient.newBuilder()
            .followRedirects(HttpClient.Redirect.NEVER)
            .connectTimeout(Duration.ofSeconds(5))
            .build();
    private final Map<String, Coordonnees> cache = new ConcurrentHashMap<>();

    public Coordonnees localiser(String lien, String adresse) {
        String cle = (lien == null ? "" : lien.strip()) + "|" + (adresse == null ? "" : adresse.strip());
        Coordonnees connues = cache.get(cle);
        if (connues != null) {
            return connues;
        }
        Optional<Coordonnees> trouvees = Optional.empty();
        if (lien != null && !lien.isBlank()) {
            trouvees = depuisLien(lien.strip()).or(() -> depuisLienCourt(lien.strip()));
        }
        if (trouvees.isEmpty()) {
            trouvees = depuisPlusCode(lien).or(() -> depuisPlusCode(adresse));
        }
        if (trouvees.isEmpty() && adresse != null && !adresse.isBlank()) {
            trouvees = geocoder(adresse.strip());
        }
        if (trouvees.isEmpty()) {
            // Repli gracieux : dépôt central de Bamako si l'adresse ou le lien ne sont pas géo-référencés
            trouvees = Optional.of(new Coordonnees(BAMAKO_LAT, BAMAKO_LNG, "defaut-bamako"));
        }
        Coordonnees c = trouvees.get();
        cache.put(cle, c);
        return c;
    }

    /** Lecture locale (sans réseau) des coordonnées présentes dans un lien Google Maps. */
    public static Optional<Coordonnees> depuisLien(String lien) {
        if (lien == null) {
            return Optional.empty();
        }
        String texte = URLDecoder.decode(lien.replace("+", "%2B"), StandardCharsets.UTF_8);
        for (Pattern p : new Pattern[] {EPINGLE, PARAMETRE, VUE, CHEMIN}) {
            Matcher m = p.matcher(texte);
            while (m.find()) {
                Optional<Coordonnees> c = valides(m.group(1), m.group(2), "lien");
                if (c.isPresent()) {
                    return c;
                }
            }
        }
        return Optional.empty();
    }

    /**
     * Plus Code Google (« JXJF+76R, Unnamed Road ») : l'adresse que Google Maps affiche pour les lieux sans numéro
     * de rue. Un code court est complété depuis le centre de Bamako (algorithme « recoverNearest » d'Open Location Code).
     */
    public static Optional<Coordonnees> depuisPlusCode(String texte) {
        if (texte == null || texte.isBlank()) {
            return Optional.empty();
        }
        String t = URLDecoder.decode(texte.replace("+", "%2B"), StandardCharsets.UTF_8).toUpperCase();
        Matcher m = PLUS_CODE.matcher(t);
        while (m.find()) {
            String avant = m.group(1);
            String apres = m.group(2);
            if (avant.length() % 2 == 1 || apres.length() == 1) {
                continue;
            }
            int manquants = 8 - avant.length();
            double[] c = decoderPlusCode(encoderPrefixe(BAMAKO_LAT, BAMAKO_LNG, manquants) + avant + apres);
            if (c == null) {
                continue;
            }
            if (manquants > 0) {
                double resolution = VALEURS_PAIRES[manquants / 2 - 1];
                double demi = resolution / 2;
                if (BAMAKO_LAT + demi < c[0] && c[0] - resolution >= -90) {
                    c[0] -= resolution;
                } else if (BAMAKO_LAT - demi > c[0] && c[0] + resolution <= 90) {
                    c[0] += resolution;
                }
                if (BAMAKO_LNG + demi < c[1]) {
                    c[1] -= resolution;
                } else if (BAMAKO_LNG - demi > c[1]) {
                    c[1] += resolution;
                }
            }
            return Optional.of(new Coordonnees(c[0], c[1], "plus-code"));
        }
        return Optional.empty();
    }

    private static String encoderPrefixe(double latitude, double longitude, int longueur) {
        double lat = Math.min(Math.max(latitude + 90, 0), 179.999999);
        double lng = ((longitude + 180) % 360 + 360) % 360;
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < longueur / 2; i++) {
            double pv = VALEURS_PAIRES[i];
            int dLat = (int) Math.min(19, Math.floor(lat / pv));
            int dLng = (int) Math.min(19, Math.floor(lng / pv));
            sb.append(ALPHABET.charAt(dLat)).append(ALPHABET.charAt(dLng));
            lat -= dLat * pv;
            lng -= dLng * pv;
        }
        return sb.toString();
    }

    /** Code complet sans « + » → centre de la zone {latitude, longitude}. */
    private static double[] decoderPlusCode(String code) {
        if (code.length() < 8 || ALPHABET.indexOf(code.charAt(0)) > 8 || ALPHABET.indexOf(code.charAt(1)) > 17) {
            return null;
        }
        double lat = 0, lng = 0, pvLat = 0, pvLng = 0;
        for (int i = 0; i < code.length() && i < 10; i += 2) {
            if (i + 1 >= code.length()) {
                return null;
            }
            pvLat = pvLng = VALEURS_PAIRES[i / 2];
            lat += ALPHABET.indexOf(code.charAt(i)) * pvLat;
            lng += ALPHABET.indexOf(code.charAt(i + 1)) * pvLng;
        }
        for (int i = 10; i < code.length(); i++) {
            int g = ALPHABET.indexOf(code.charAt(i));
            pvLat /= 5;
            pvLng /= 4;
            lat += (g / 4) * pvLat;
            lng += (g % 4) * pvLng;
        }
        return new double[] {lat + pvLat / 2 - 90, lng + pvLng / 2 - 180};
    }

    private Optional<Coordonnees> depuisLienCourt(String lien) {
        String courant = lien;
        try {
            for (int i = 0; i < REDIRECTIONS_MAX; i++) {
                URI uri = URI.create(courant);
                if (!"https".equalsIgnoreCase(uri.getScheme()) && !"http".equalsIgnoreCase(uri.getScheme())) {
                    return Optional.empty();
                }
                String hote = uri.getHost() == null ? "" : uri.getHost().toLowerCase();
                if (!HOTE_GOOGLE.matcher(hote).matches()) {
                    return Optional.empty();
                }
                HttpResponse<Void> r = http.send(HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(5)).GET().build(),
                        HttpResponse.BodyHandlers.discarding());
                Optional<String> suivant = r.headers().firstValue("location");
                if (r.statusCode() / 100 != 3 || suivant.isEmpty()) {
                    return Optional.empty();
                }
                courant = uri.resolve(suivant.get()).toString();
                Optional<Coordonnees> c = depuisLien(courant);
                if (c.isPresent()) {
                    return c;
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            LOG.debug("Lien Google Maps non résolu : {}", lien, e);
        }
        return Optional.empty();
    }

    private Optional<Coordonnees> geocoder(String adresse) {
        String q = adresse.toLowerCase().contains("mali") ? adresse : adresse + ", Mali";
        try {
            URI uri = URI.create("https://nominatim.openstreetmap.org/search?format=json&limit=1&q="
                    + URLEncoder.encode(q, StandardCharsets.UTF_8));
            HttpResponse<String> r = http.send(HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofSeconds(6))
                    .header("User-Agent", "DoGo/1.0 (achats groupes B2B Mali)")
                    .GET().build(), HttpResponse.BodyHandlers.ofString());
            if (r.statusCode() == 200) {
                Matcher m = NOMINATIM.matcher(r.body());
                if (m.find()) {
                    return valides(m.group(1), m.group(2), "adresse");
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            LOG.debug("Géocodage impossible : {}", adresse, e);
        }
        return Optional.empty();
    }

    private static Optional<Coordonnees> valides(String lat, String lng, String source) {
        try {
            double la = Double.parseDouble(lat);
            double lo = Double.parseDouble(lng);
            if (Math.abs(la) <= 90 && Math.abs(lo) <= 180 && !(la == 0 && lo == 0)) {
                return Optional.of(new Coordonnees(la, lo, source));
            }
        } catch (NumberFormatException ignore) {
            // ignoré : on essaie le motif suivant
        }
        return Optional.empty();
    }
}
