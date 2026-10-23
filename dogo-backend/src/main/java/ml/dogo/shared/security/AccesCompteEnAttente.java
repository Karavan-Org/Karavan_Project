package ml.dogo.shared.security;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.http.HttpMethod;
import org.springframework.util.AntPathMatcher;

/**
 * RG-03 : un compte en attente de validation (Grossiste ou Courtier) ne peut que suivre son parcours de
 * vérification. Liste blanche appliquée à toute l'API, quelle que soit la permission portée par le jeton :
 * une nouvelle route est fermée aux comptes en attente tant qu'elle n'est pas ajoutée ici.
 */
public final class AccesCompteEnAttente {

    /** Autorité ajoutée par {@link JwtFiltre} aux requêtes d'un compte en attente. */
    public static final String MARQUEUR = "STATUT_COMPTE_EN_ATTENTE";

    private record Route(HttpMethod methode, String motif) {
    }

    private static final List<Route> AUTORISEES = List.of(
            // Profil : lecture, mot de passe, photo et déconnexion (pas de modification des informations déclarées)
            new Route(HttpMethod.GET, "/api/moi"),
            new Route(HttpMethod.POST, "/api/moi/deconnexion"),
            new Route(HttpMethod.POST, "/api/moi/mot-de-passe"),
            new Route(HttpMethod.POST, "/api/moi/photo"),
            // Notifications (dont « dossier approuvé / rejeté »)
            new Route(HttpMethod.GET, "/api/moi/notifications"),
            new Route(HttpMethod.POST, "/api/moi/notifications/*/lue"),
            // Dossier de vérification (RG-04)
            new Route(HttpMethod.POST, "/api/kyc"),
            new Route(HttpMethod.GET, "/api/kyc/moi"),
            // Routes publiques : un compte en attente n'a pas moins de droits qu'un visiteur
            new Route(null, "/api/auth/**"),
            new Route(HttpMethod.GET, "/api/groupes/**"),
            new Route(HttpMethod.GET, "/api/catalogue/categories"),
            new Route(HttpMethod.GET, "/api/public/images/**"),
            new Route(HttpMethod.GET, "/api/public/contact"));

    private static final AntPathMatcher CHEMINS = new AntPathMatcher();

    private AccesCompteEnAttente() {
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
