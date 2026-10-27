package ml.dogo.shared.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * RG-03 : refuse à un compte en attente de validation toute route hors de son parcours de vérification
 * ({@link AccesCompteEnAttente}). Placé juste après {@link JwtFiltre} ; instancié dans {@link SecurityConfig}
 * pour la même raison que lui (pas de double enregistrement comme filtre de servlet).
 */
public class FiltreCompteEnAttente extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest requete, HttpServletResponse reponse, FilterChain chaine)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean enAttente = auth != null && auth.getAuthorities().stream()
                .anyMatch(a -> AccesCompteEnAttente.MARQUEUR.equals(a.getAuthority()));
        if (enAttente && !AccesCompteEnAttente.autorise(requete)) {
            // Même format que GestionnaireErreurs (ProblemDetail : code et règle lus par les applications)
            reponse.setStatus(HttpServletResponse.SC_FORBIDDEN);
            reponse.setContentType("application/problem+json;charset=UTF-8");
            reponse.getWriter().write("{\"status\":403,\"code\":\"COMPTE_INACTIF\",\"regle\":\"RG-03\","
                    + "\"detail\":\"Compte en attente de validation : cette action sera disponible "
                    + "dès que votre dossier aura été approuvé par l'administrateur.\"}");
            return;
        }
        chaine.doFilter(requete, reponse);
    }
}
