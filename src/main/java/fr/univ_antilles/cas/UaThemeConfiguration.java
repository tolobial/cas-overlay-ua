package fr.univ_antilles.cas;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Configuration Spring du thème UA pour CAS 7.3.
 *
 * Déclarée comme @AutoConfiguration et référencée dans
 *   src/main/resources/META-INF/spring/
 *     org.springframework.boot.autoconfigure.AutoConfiguration.imports
 *
 * Expose deux beans :
 *
 *   1. uaPhotos (UaPhotosBean) : exposé à Thymeleaf via ${@uaPhotos.list()}.
 *      Le nom du bean = nom de la méthode = "uaPhotos".
 *
 *   2. uaThemeWebMvcConfigurer : enregistre le ResourceHandler qui mappe
 *      l'URL /themes/ua/photos/** vers /etc/cas/themes/ua/photos/.
 *
 * NB : Plus de HandlerInterceptor — il ne fonctionne pas avec les vues
 * Spring Webflow (utilisées par CAS pour le login). Voir le commentaire
 * de classe de UaPhotosBean pour les détails.
 */
@AutoConfiguration
public class UaThemeConfiguration {

    /**
     * Bean nommé "uaPhotos" (nom dérivé du nom de la méthode).
     * Accessible depuis Thymeleaf via la syntaxe ${@uaPhotos.list()}.
     */
    @Bean
    public UaPhotosBean uaPhotos() {
        return new UaPhotosBean();
    }

    /**
     * Mappe les requêtes HTTP /themes/ua/photos/** vers les fichiers
     * physiques de /etc/cas/themes/ua/photos/. Exemple :
     *   GET /cas/themes/ua/photos/Guadeloupe/marina.jpg
     *   → /etc/cas/themes/ua/photos/Guadeloupe/marina.jpg
     *
     * NB : le préfixe "/cas" provient du context path de Tomcat — pas
     * besoin de le déclarer ici, Spring le gère automatiquement.
     */
    @Bean
    public WebMvcConfigurer uaThemeWebMvcConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addResourceHandlers(ResourceHandlerRegistry registry) {
                registry.addResourceHandler("/themes/ua/photos/**")
                        .addResourceLocations("file:/etc/cas/themes/ua/photos/");
            }
        };
    }
}
