package fr.univ_antilles.cas;

import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Bean Spring exposant la liste de photos UA à Thymeleaf.
 *
 * Accessible directement depuis les templates Thymeleaf :
 *   ${@uaPhotos.list()}
 *
 * ──────────────────────────────────────────────────────────────────────
 * POURQUOI UN BEAN ET NON UN HandlerInterceptor ?
 *
 * Première itération : on avait un UaPhotosInterceptor qui posait
 * ${uaPhotos} dans le ModelAndView via postHandle(). Ça ne marche PAS
 * pour les vues CAS car CAS utilise Spring Webflow, qui :
 *   - intercepte le rendu via son propre FlowExecutor
 *   - n'appelle pas HandlerInterceptor.postHandle() avec le bon
 *     ModelAndView pour les view-states du flow
 *
 * Résultat : ${uaPhotos} restait vide dans la vue → 0 slide rendue.
 *
 * Solution : exposer la liste comme un BEAN SPRING que Thymeleaf appelle
 * directement via la syntaxe ${@beanName.method()}. Indépendant du
 * mécanisme de rendu (MVC ou Webflow).
 * ──────────────────────────────────────────────────────────────────────
 *
 * Comportement :
 *   - Scanne /etc/cas/themes/ua/photos/{Guadeloupe,Martinique}/
 *   - Tire 5 photos au hasard dans chaque sous-dossier
 *   - Mélange les 10 et retourne la liste
 *   - Chaque entrée : { "url": "/cas/themes/ua/photos/...", "pole": "..." }
 *
 * Le scan est fait à CHAQUE appel (donc à chaque login). Coût négligeable
 * (lister 20 fichiers : ~µs). Avantage : photos ajoutées/retirées au
 * dossier prises en compte immédiatement, zéro redémarrage.
 */
public class UaPhotosBean {

    /** Dossier racine contenant les sous-dossiers des pôles. */
    private static final Path PHOTOS_ROOT = Paths.get("/etc/cas/themes/ua/photos");

    /**
     * Liste des pôles à parcourir.
     * ⚠️ Casse-sensitive : doit correspondre aux noms de sous-dossiers.
     */
    private static final List<String> POLES = List.of("Guadeloupe", "Martinique");

    /** Nombre de photos tirées par pôle. */
    private static final int PHOTOS_PER_POLE = 5;

    /** Chemin URL (relatif au context path) des photos. */
    private static final String URL_PATH = "/themes/ua/photos/";

    /** Extensions acceptées (insensible à la casse). */
    private static final List<String> ALLOWED_EXTENSIONS =
            List.of(".jpg", ".jpeg", ".png", ".webp");

    /**
     * Point d'entrée appelé depuis Thymeleaf : ${@uaPhotos.list()}
     * Retourne 10 photos mélangées (5 par pôle).
     */
    public List<Map<String, String>> list() {
        String contextPath = currentContextPath();
        List<Map<String, String>> all = new ArrayList<>();
        for (String pole : POLES) {
            all.addAll(listAndPick(pole, PHOTOS_PER_POLE, contextPath));
        }
        Collections.shuffle(all);
        return all;
    }

    /**
     * Récupère le contextPath de la requête en cours via Spring's
     * RequestContextHolder (un thread-local). Si on est hors d'une
     * requête HTTP (cas pathologique), retourne "".
     */
    private String currentContextPath() {
        try {
            ServletRequestAttributes attrs =
                (ServletRequestAttributes) RequestContextHolder.currentRequestAttributes();
            return attrs.getRequest().getContextPath();
        } catch (IllegalStateException e) {
            return "";
        }
    }

    private List<Map<String, String>> listAndPick(String pole, int n, String contextPath) {
        Path dir = PHOTOS_ROOT.resolve(pole);
        if (!Files.isDirectory(dir)) {
            return Collections.emptyList();
        }
        try (Stream<Path> files = Files.list(dir)) {
            List<Map<String, String>> all = files
                    .filter(Files::isRegularFile)
                    .filter(this::hasAllowedExtension)
                    .map(p -> toEntry(p, pole, contextPath))
                    .collect(Collectors.toCollection(ArrayList::new));
            Collections.shuffle(all);
            return all.stream().limit(n).collect(Collectors.toList());
        } catch (IOException e) {
            return Collections.emptyList();
        }
    }

    private boolean hasAllowedExtension(Path p) {
        String name = p.getFileName().toString().toLowerCase();
        return ALLOWED_EXTENSIONS.stream().anyMatch(name::endsWith);
    }

    private Map<String, String> toEntry(Path file, String pole, String contextPath) {
        Map<String, String> entry = new HashMap<>();
        entry.put("url", contextPath + URL_PATH + pole + "/" + file.getFileName());
        entry.put("pole", pole);
        return entry;
    }
}
