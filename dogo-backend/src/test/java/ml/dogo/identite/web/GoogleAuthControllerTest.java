package ml.dogo.identite.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import ml.dogo.identite.application.AuthService;
import ml.dogo.identite.application.GoogleAuthService;
import ml.dogo.identite.domain.TypeActeur;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class GoogleAuthControllerTest {

    private final GoogleAuthService googleAuthService = mock(GoogleAuthService.class);
    private final GoogleAuthController controller = new GoogleAuthController(googleAuthService);

    private final Instant expiration = Instant.parse("2030-01-01T00:00:00Z");
    private final AuthService.Profil profil = new AuthService.Profil(
            10, "COMMERCANT", "Salif Commerçant", "+22375000001", null, "ACTIF", List.of("COMMANDE_CREER"));

    @BeforeEach
    void setup() {
    }

    @Test
    void subConnuConnecteEtPoseLeCookieRefreshToken() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();

        GoogleAuthService.ResultatAuthGoogle connecte = GoogleAuthService.ResultatAuthGoogle.connecte(
                "mock-access-jwt", "mock-refresh-token", expiration, expiration, profil);

        when(googleAuthService.authentifier(anyString(), any(), anyString())).thenReturn(connecte);

        ResponseEntity<?> rep = controller.authentifier(
                new GoogleAuthController.GoogleTokenRequete("mon-id-token-google", "dev-1"), request, response);

        assertEquals(200, rep.getStatusCode().value());
        AuthController.ReponseSession session = (AuthController.ReponseSession) rep.getBody();
        assertNotNull(session);
        assertEquals("mock-access-jwt", session.jeton());
        assertEquals("mock-refresh-token", session.refreshToken());
        assertNotNull(response.getHeader("Set-Cookie"));
    }

    @Test
    void subInconnuRenvoieProfilIncompletSansCookie() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();

        GoogleAuthService.ResultatAuthGoogle incomplet = new GoogleAuthService.ResultatAuthGoogle(
                "PROFIL_INCOMPLET", "temp-reg-token-xyz", "sub-12345", "salif@gmail.com",
                true, "Salif Keïta", "https://photo.url", null, null, null, null, null);

        when(googleAuthService.authentifier(anyString(), any(), anyString())).thenReturn(incomplet);

        ResponseEntity<?> rep = controller.authentifier(
                new GoogleAuthController.GoogleTokenRequete("id-token-nouveau", "dev-1"), request, response);

        assertEquals(200, rep.getStatusCode().value());
        GoogleAuthService.ResultatAuthGoogle body = (GoogleAuthService.ResultatAuthGoogle) rep.getBody();
        assertNotNull(body);
        assertEquals("PROFIL_INCOMPLET", body.statut());
        assertEquals("temp-reg-token-xyz", body.jetonInscription());
        assertNull(response.getHeader("Set-Cookie"));
    }

    @Test
    void completerSansOtpDeclencheEnvoiOtp() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();

        when(googleAuthService.declencherOtpCompleter(anyString(), anyString(), anyString())).thenReturn(
                new GoogleAuthService.ReponseOtpGoogle("OTP_ENVOYE", "+22375000001", "SMS envoyé", "1234"));

        GoogleAuthController.GoogleCompleterRequete req = new GoogleAuthController.GoogleCompleterRequete(
                "temp-token", "+22375000001", null, TypeActeur.COMMERCANT, "Boutique", "Marché", "dev-1");

        ResponseEntity<?> rep = controller.completer(req, request, response);

        assertEquals(200, rep.getStatusCode().value());
        GoogleAuthService.ReponseOtpGoogle repOtp = (GoogleAuthService.ReponseOtpGoogle) rep.getBody();
        assertNotNull(repOtp);
        assertEquals("OTP_ENVOYE", repOtp.statut());
        assertEquals("1234", repOtp.codeOtp());
    }

    @Test
    void completerAvecOtpValideOuvreSession() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();

        when(googleAuthService.completerEtConnecter(any(), anyString())).thenReturn(
                new AuthService.Connexion("new-access-jwt", "new-refresh-token", expiration, expiration, profil));

        GoogleAuthController.GoogleCompleterRequete req = new GoogleAuthController.GoogleCompleterRequete(
                "temp-token", "+22375000001", "1234", TypeActeur.COMMERCANT, "Boutique", "Marché", "dev-1");

        ResponseEntity<?> rep = controller.completer(req, request, response);

        assertEquals(200, rep.getStatusCode().value());
        AuthController.ReponseSession session = (AuthController.ReponseSession) rep.getBody();
        assertNotNull(session);
        assertEquals("new-access-jwt", session.jeton());
        assertEquals("new-refresh-token", session.refreshToken());
        assertNotNull(response.getHeader("Set-Cookie"));
    }
}

