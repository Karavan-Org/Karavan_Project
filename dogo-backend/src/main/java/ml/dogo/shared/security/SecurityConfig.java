package ml.dogo.shared.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * API sans état : chaque requête porte un jeton JWT. Les droits fins sont posés sur les méthodes
 * avec {@code @PreAuthorize("hasAuthority('...')")} (RG-06).
 */
@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain chaineDeSecurite(HttpSecurity http, JwtService jwt, VerificateurSession sessions)
            throws Exception {
        JwtFiltre filtre = new JwtFiltre(jwt, sessions);
        http.csrf(c -> c.disable())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/paiements/callback").permitAll()
                        .requestMatchers("/api/dev/**").permitAll()
                        .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                        .requestMatchers("/actuator/health").permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req, res, ex) -> ecrire(res, 401, "Authentification requise"))
                        .accessDeniedHandler((req, res, ex) -> ecrire(res, 403, "Accès refusé")))
                .addFilterBefore(filtre, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    private static void ecrire(jakarta.servlet.http.HttpServletResponse res, int statut, String detail)
            throws java.io.IOException {
        res.setStatus(statut);
        res.setContentType("application/problem+json;charset=UTF-8");
        res.getWriter().write("{\"status\":" + statut + ",\"detail\":\"" + detail + "\"}");
    }
}
