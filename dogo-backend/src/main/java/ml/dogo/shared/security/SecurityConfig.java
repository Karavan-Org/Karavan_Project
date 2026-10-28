package ml.dogo.shared.security;

import java.util.Arrays;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * API sans état : chaque requête porte un jeton JWT. Les droits fins sont posés sur les méthodes
 * avec {@code @PreAuthorize("hasAuthority('...')")} (RG-06).
 */
@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain chaineDeSecurite(HttpSecurity http, JwtService jwt, VerificateurSession sessions,
                                               CorsConfigurationSource corsConfigurationSource)
            throws Exception {
        JwtFiltre filtre = new JwtFiltre(jwt, sessions);
        http.cors(c -> c.configurationSource(corsConfigurationSource))
                .csrf(c -> c.disable())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/groupes/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/pays/**").permitAll()
                        .requestMatchers("/api/catalogue/categories").permitAll()
                        .requestMatchers("/api/public/images/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/public/contact").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/paiements/callback").permitAll()
                        .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                        .requestMatchers("/actuator/health").permitAll()
                        .requestMatchers("/error").permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req, res, ex) -> ecrire(res, 401, "Authentification requise"))
                        .accessDeniedHandler((req, res, ex) -> ecrire(res, 403, "Accès refusé")))
                .addFilterBefore(filtre, UsernamePasswordAuthenticationFilter.class)
                // RG-03 : un compte en attente de validation n'accède qu'à son parcours de vérification
                .addFilterAfter(new FiltreCompteEnAttente(), JwtFiltre.class);
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource(
            @Value("${dogo.cors.origines:http://localhost:[*],http://127.0.0.1:[*],http://10.0.2.2:[*]}") String origines) {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(Arrays.stream(origines.split(","))
                .map(String::trim).filter(s -> !s.isEmpty()).toList());
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
        config.setAllowedHeaders(List.of(
                "Authorization",
                "Content-Type",
                "Idempotency-Key",
                "X-Signature",
                "X-Client-Platform",
                "Accept",
                "Origin",
                "X-Requested-With",
                "Access-Control-Request-Private-Network"
        ));
        config.setExposedHeaders(List.of("Idempotency-Key", "Authorization", "Access-Control-Allow-Private-Network"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    private static void ecrire(jakarta.servlet.http.HttpServletResponse res, int statut, String detail)
            throws java.io.IOException {
        res.setStatus(statut);
        res.setContentType("application/problem+json;charset=UTF-8");
        res.getWriter().write("{\"status\":" + statut + ",\"detail\":\"" + detail + "\"}");
    }
}
