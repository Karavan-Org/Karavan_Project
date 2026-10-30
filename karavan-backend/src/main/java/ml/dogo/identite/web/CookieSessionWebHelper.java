package ml.dogo.identite.web;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Duration;
import java.time.Instant;
import ml.dogo.identite.application.AuthService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;

/**
 * Helper HTTP partagé (DRY) pour la gestion du cookie HttpOnly de refresh token
 * et le formatage des réponses de session entre l'authentification classique et Google OAuth2.
 *
 * <p>Isole le cookie de la console d'administration ({@code dogo_admin_refresh_token}) de celui
 * de l'application web B2B ({@code dogo_app_refresh_token}) afin que les deux puissent cohabiter
 * simultanément dans le même navigateur (ex. localhost:4200 et localhost:3000) sans collision.
 */
final class CookieSessionWebHelper {

    static final String CLIENT_HEADER = "X-Client-Platform";
    static final String CONSOLE_ADMIN = "admin-console";
    static final String FLUTTER_WEB = "flutter-web";
    static final String COOKIE_NAME = "dogo_refresh_token";
    static final String ADMIN_COOKIE_NAME = "dogo_admin_refresh_token";
    static final String APP_COOKIE_NAME = "dogo_app_refresh_token";

    private CookieSessionWebHelper() {
    }

    static String nomCookiePour(HttpServletRequest request) {
        String client = request != null ? request.getHeader(CLIENT_HEADER) : null;
        if (CONSOLE_ADMIN.equalsIgnoreCase(client)) {
            return ADMIN_COOKIE_NAME;
        }
        if (FLUTTER_WEB.equalsIgnoreCase(client)) {
            return APP_COOKIE_NAME;
        }
        return COOKIE_NAME;
    }

    static boolean cookieSecurise(HttpServletRequest request, boolean cookiesSecurisesConfig) {
        return request.isSecure() || cookiesSecurisesConfig;
    }

    static AuthController.ReponseSession formaterReponseSession(String jeton,
                                                                String refreshToken,
                                                                Instant expiration,
                                                                Instant refreshExpiration,
                                                                AuthService.Profil profil,
                                                                HttpServletRequest request) {
        String client = request.getHeader(CLIENT_HEADER);
        boolean exposeRefreshToken = !CONSOLE_ADMIN.equalsIgnoreCase(client)
                && !FLUTTER_WEB.equalsIgnoreCase(client);
        return new AuthController.ReponseSession(
                jeton,
                exposeRefreshToken ? refreshToken : null,
                expiration,
                exposeRefreshToken ? refreshExpiration : null,
                profil);
    }

    static String extraireRefreshToken(String fromBody, HttpServletRequest request) {
        if (fromBody != null && !fromBody.isBlank()) {
            return fromBody.trim();
        }
        if (request.getCookies() != null) {
            String attendu = nomCookiePour(request);
            for (Cookie c : request.getCookies()) {
                if (attendu.equals(c.getName()) && c.getValue() != null && !c.getValue().isBlank()) {
                    return c.getValue().trim();
                }
            }
            // Rétrocompatibilité si seul le cookie historique générique est présent
            for (Cookie c : request.getCookies()) {
                if (COOKIE_NAME.equals(c.getName()) && c.getValue() != null && !c.getValue().isBlank()) {
                    return c.getValue().trim();
                }
            }
        }
        return null;
    }

    static void poserCookie(HttpServletRequest request,
                            HttpServletResponse response,
                            String token,
                            boolean isSecure,
                            Instant expiration) {
        String nom = nomCookiePour(request);
        long maxAge = Math.max(0, Duration.between(Instant.now(), expiration).toSeconds());
        ResponseCookie cookie = ResponseCookie.from(nom, token)
                .httpOnly(true)
                .secure(isSecure)
                .path("/api")
                .sameSite("Lax")
                .maxAge(maxAge)
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
        if (!COOKIE_NAME.equals(nom)) {
            expirerCookie(response, COOKIE_NAME, isSecure);
        }
    }

    static void supprimerCookie(HttpServletRequest request, HttpServletResponse response, boolean isSecure) {
        String nom = nomCookiePour(request);
        expirerCookie(response, nom, isSecure);
        if (!COOKIE_NAME.equals(nom)) {
            expirerCookie(response, COOKIE_NAME, isSecure);
        }
    }

    private static void expirerCookie(HttpServletResponse response, String nom, boolean isSecure) {
        ResponseCookie cookie = ResponseCookie.from(nom, "")
                .httpOnly(true)
                .secure(isSecure)
                .path("/api")
                .sameSite("Lax")
                .maxAge(0)
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }
}
