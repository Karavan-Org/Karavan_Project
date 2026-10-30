package ml.dogo.shared.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Lit le jeton « Bearer », vérifie la session et place l'utilisateur dans le contexte de sécurité.
 * Volontairement pas un {@code @Component} : Spring Boot l'enregistrerait aussi comme filtre de servlet, avant la chaîne
 * de sécurité, et l'authentification serait effacée. Il est instancié dans {@link SecurityConfig}.
 */
public class JwtFiltre extends OncePerRequestFilter {

    private final JwtService jwt;
    private final VerificateurSession sessions;

    public JwtFiltre(JwtService jwt, VerificateurSession sessions) {
        this.jwt = jwt;
        this.sessions = sessions;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest requete, HttpServletResponse reponse, FilterChain chaine)
            throws ServletException, IOException {
        String entete = requete.getHeader("Authorization");
        if (entete != null && entete.startsWith("Bearer ")) {
            Optional<JwtService.JetonInfo> info = jwt.lire(entete.substring(7));
            EtatSession etat = info.isEmpty() ? EtatSession.INVALIDE
                    : sessions.verifierEtProlonger(info.get().sessionId(), info.get().utilisateurId());
            if (etat != EtatSession.INVALIDE) {
                JwtService.JetonInfo j = info.get();
                List<GrantedAuthority> autorites = new ArrayList<>(j.permissions().stream()
                        .<GrantedAuthority>map(SimpleGrantedAuthority::new).toList());
                if (j.type() != null && !j.type().isBlank()) {
                    autorites.add(new SimpleGrantedAuthority("ROLE_" + j.type().trim().toUpperCase()));
                }
                if (etat == EtatSession.EN_ATTENTE) {
                    // Lu par FiltreCompteEnAttente : seul le parcours de vérification reste ouvert (RG-03)
                    autorites.add(new SimpleGrantedAuthority(AccesCompteEnAttente.MARQUEUR));
                } else if (etat == EtatSession.MOT_DE_PASSE_PROVISOIRE) {
                    // Lu par FiltreMotDePasseProvisoire : seul le changement de mot de passe reste ouvert (RG-07b)
                    autorites.add(new SimpleGrantedAuthority(AccesMotDePasseProvisoire.MARQUEUR));
                }
                UtilisateurCourant courant = new UtilisateurCourant(j.utilisateurId(), j.type(), j.permissions(), j.sessionId());
                SecurityContextHolder.getContext()
                        .setAuthentication(new UsernamePasswordAuthenticationToken(courant, null, autorites));
            }
        }
        chaine.doFilter(requete, reponse);
    }
}
