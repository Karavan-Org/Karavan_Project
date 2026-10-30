package ml.dogo.shared.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Documentation Swagger : le bouton « Authorize » accepte le jeton JWT obtenu par POST /api/auth/connexion. */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI dogoOpenApi() {
        return new OpenAPI()
                .info(new Info().title("DoGo — API").version("1.0")
                        .description("Achats groupés Chine → Mali : groupes, paiements en séquestre, logistique et retrait."))
                .components(new Components().addSecuritySchemes("jwt",
                        new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")))
                .addSecurityItem(new SecurityRequirement().addList("jwt"));
    }
}
