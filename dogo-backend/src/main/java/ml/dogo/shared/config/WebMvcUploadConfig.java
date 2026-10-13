package ml.dogo.shared.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.CacheControl;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.concurrent.TimeUnit;

@Configuration
public class WebMvcUploadConfig implements WebMvcConfigurer {

    @Value("${dogo.stockage.repertoire:uploads/produits}")
    private String cheminUpload;

    @Value("${dogo.stockage.repertoire-avatars:uploads/avatars}")
    private String cheminAvatars;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        Path uploadPath = Paths.get(cheminUpload).toAbsolutePath().normalize();
        String fileUri = uploadPath.toUri().toString();
        if (!fileUri.endsWith("/")) {
            fileUri += "/";
        }

        registry.addResourceHandler("/api/public/images/produits/**")
                .addResourceLocations(fileUri)
                .setCacheControl(CacheControl.maxAge(30, TimeUnit.DAYS).cachePublic());

        Path avatarsPath = Paths.get(cheminAvatars).toAbsolutePath().normalize();
        String avatarsUri = avatarsPath.toUri().toString();
        if (!avatarsUri.endsWith("/")) {
            avatarsUri += "/";
        }

        registry.addResourceHandler("/api/public/images/avatars/**")
                .addResourceLocations(avatarsUri)
                .setCacheControl(CacheControl.maxAge(30, TimeUnit.DAYS).cachePublic());
    }
}

