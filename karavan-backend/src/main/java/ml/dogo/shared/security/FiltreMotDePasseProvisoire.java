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
 * RG-07b : refuse à un compte au mot de passe provisoire toute route hors du changement de mot de passe
 * ({@link AccesMotDePasseProvisoire}). Instancié dans {@link SecurityConfig}, comme {@link FiltreCompteEnAttente}.
 */
public class FiltreMotDePasseProvisoire extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest requete, HttpServletResponse reponse, FilterChain chaine)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean provisoire = auth != null && auth.getAuthorities().stream()
                .anyMatch(a -> AccesMotDePasseProvisoire.MARQUEUR.equals(a.getAuthority()));
        if (provisoire && !AccesMotDePasseProvisoire.autorise(requete)) {
            // Même format que GestionnaireErreurs : le code est lu par les applications pour ouvrir l'écran dédié
            reponse.setStatus(HttpServletResponse.SC_FORBIDDEN);
            reponse.setContentType("application/problem+json;charset=UTF-8");
            reponse.getWriter().write("{\"status\":403,\"code\":\"MOT_DE_PASSE_PROVISOIRE\",\"regle\":\"RG-07b\","
                    + "\"detail\":\"Votre mot de passe est provisoire : choisissez votre propre mot de passe "
                    + "pour accéder à la plateforme.\"}");
            return;
        }
        chaine.doFilter(requete, reponse);
    }
}
