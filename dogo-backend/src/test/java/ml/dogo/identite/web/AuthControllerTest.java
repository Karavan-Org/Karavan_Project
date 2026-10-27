package ml.dogo.identite.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import jakarta.servlet.http.Cookie;
import java.time.Instant;
import java.util.List;
import ml.dogo.identite.application.AuthService;
import ml.dogo.identite.application.InscriptionService;
import ml.dogo.identite.application.RefreshTokenService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class AuthControllerTest {

    private final AuthService auth = mock(AuthService.class);
    private final RefreshTokenService refreshTokens = mock(RefreshTokenService.class);
    private final AuthController controller = new AuthController(mock(InscriptionService.class), auth, refreshTokens);
    private final Instant expiration = Instant.parse("2030-01-01T00:00:00Z");
    private final AuthService.Profil profil = new AuthService.Profil(
            1, "ADMINISTRATEUR", "Admin", "+22370000001", null, "ACTIF", List.of("ADMIN_CREER"));

    @BeforeEach
    void preparerConnexion() {
        when(auth.connecter(anyString(), anyString(), isNull(), anyString()))
                .thenReturn(new AuthService.Connexion("access", "refresh", expiration, expiration, profil));
    }

    @Test
    void leClientMobileRecoitLeRefreshTokenDansLeCorps() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();

        AuthController.ReponseSession resultat = controller.connecter(
                new AuthController.ConnexionRequete("+22370000001", "mot-de-passe", null, null), request, response);

        assertEquals("refresh", resultat.refreshToken());
        assertNotNull(response.getHeader("Set-Cookie"));
    }

    @Test
    void laConsoleAdminUtiliseLeCookieSansRecevoirLeRefreshTokenDansLeCorps() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Client-Platform", "admin-console");
        request.setSecure(true);
        MockHttpServletResponse response = new MockHttpServletResponse();

        AuthController.ReponseSession resultat = controller.connecter(
                new AuthController.ConnexionRequete("+22370000001", "mot-de-passe", null, null), request, response);

        assertNull(resultat.refreshToken());
        assertNull(resultat.refreshExpiration());
        assertEquals("access", resultat.jeton());
        String cookie = response.getHeader("Set-Cookie");
        assertNotNull(cookie);
        org.junit.jupiter.api.Assertions.assertTrue(cookie.contains("HttpOnly"));
        org.junit.jupiter.api.Assertions.assertTrue(cookie.contains("Secure"));
    }

    @Test
    void flutterWebUtiliseUnCookieHttpOnlySansRecevoirLeRefreshTokenDansLeCorps() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Client-Platform", "flutter-web");
        request.setSecure(true);
        MockHttpServletResponse response = new MockHttpServletResponse();

        AuthController.ReponseSession resultat = controller.connecter(
                new AuthController.ConnexionRequete("+22370000001", "mot-de-passe", null, null), request, response);

        assertNull(resultat.refreshToken());
        assertNull(resultat.refreshExpiration());
        org.junit.jupiter.api.Assertions.assertTrue(response.getHeader("Set-Cookie").contains("HttpOnly"));
        org.junit.jupiter.api.Assertions.assertTrue(response.getHeader("Set-Cookie").contains("Secure"));
    }

    @Test
    void leRafraichissementDeLaConsoleAdminNeRetournePasLeRefreshTokenDansLeCorps() {
        RefreshTokenService.TokenPair pair = new RefreshTokenService.TokenPair(
                "access-renouvele", "refresh-renouvele", expiration, expiration, profil);
        when(refreshTokens.rafraichir("refresh", null, "127.0.0.1")).thenReturn(pair);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Client-Platform", "admin-console");
        request.setSecure(true);
        request.setCookies(new Cookie("dogo_refresh_token", "refresh"));
        MockHttpServletResponse response = new MockHttpServletResponse();

        AuthController.ReponseSession resultat = controller.rafraichir(null, request, response).getBody();

        assertNotNull(resultat);
        assertEquals("access-renouvele", resultat.jeton());
        assertNull(resultat.refreshToken());
        assertNotNull(response.getHeader("Set-Cookie"));
    }

    @Test
    void leRafraichissementFlutterWebNeRetournePasLeRefreshTokenDansLeCorps() {
        RefreshTokenService.TokenPair pair = new RefreshTokenService.TokenPair(
                "access-renouvele", "refresh-renouvele", expiration, expiration, profil);
        when(refreshTokens.rafraichir("refresh", null, "127.0.0.1")).thenReturn(pair);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Client-Platform", "flutter-web");
        request.setSecure(true);
        request.setCookies(new Cookie("dogo_refresh_token", "refresh"));
        MockHttpServletResponse response = new MockHttpServletResponse();

        AuthController.ReponseSession resultat = controller.rafraichir(null, request, response).getBody();

        assertNotNull(resultat);
        assertEquals("access-renouvele", resultat.jeton());
        assertNull(resultat.refreshToken());
        assertNotNull(response.getHeader("Set-Cookie"));
    }
}
