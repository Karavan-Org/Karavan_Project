package ml.dogo.shared.security;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.http.HttpMethod;
import org.springframework.util.AntPathMatcher;

/**
 * RG-07b : un compte dont le mot de passe est provisoire (fixé par un tiers) ne peut que le remplacer.
 * Liste blanche appliquée à toute l'API, quelle que soit la permission portée par le jeton.
 */
public final class AccesMotDePasseProvisoire {

    /** Autorité ajoutée par {@link JwtFiltre} aux requêtes d'un compte au mot de passe provisoire. */
    public static final String MARQUEUR = "MOT_DE_PASSE_PROVISOIRE";

    private record Route(HttpMethod methode, String motif) {
    }

    private static final List<Route> AUTORISEES = List.of(
            new Route(HttpMethod.GET, "/api/moi"),
            new Route(HttpMethod.POST, "/api/moi/mot-de-passe"),
            new Route(HttpMethod.POST, "/api/moi/deconnexion"),
            new Route(null, "/api/auth/**"));

    private static final AntPathMatcher CHEMINS = new AntPathMatcher();

    private AccesMotDePasseProvisoire() {
    }

    public static boolean autorise(HttpServletRequest requete) {
        String chemin = requete.getRequestURI().substring(requete.getContextPath().length());
        String methode = requete.getMethod();
        if (HttpMethod.OPTIONS.matches(methode)) {
            return true;
        }
        return AUTORISEES.stream().anyMatch(r ->
                (r.methode() == null || r.methode().matches(methode)) && CHEMINS.match(r.motif(), chemin));
    }
}
