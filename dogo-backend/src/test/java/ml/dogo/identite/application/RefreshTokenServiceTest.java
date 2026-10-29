package ml.dogo.identite.application;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;
import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.Commercant;
import ml.dogo.identite.persistence.RefreshToken;
import ml.dogo.identite.persistence.RefreshTokenRepository;
import ml.dogo.identite.persistence.Role;
import ml.dogo.identite.persistence.SessionUtilisateur;
import ml.dogo.identite.persistence.SessionUtilisateurRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class RefreshTokenServiceTest {

    private RefreshTokenRepository refreshTokenRepository;
    private UtilisateurRepository utilisateurRepository;
    private SessionUtilisateurRepository sessionRepository;
    private SessionService sessionService;
    private JwtService jwtService;
    private DogoProperties proprietes;
    private Clock horloge;

    private RefreshTokenService service;
    private Instant maintenant;

    @BeforeEach
    void setUp() {
        refreshTokenRepository = mock(RefreshTokenRepository.class);
        utilisateurRepository = mock(UtilisateurRepository.class);
        sessionRepository = mock(SessionUtilisateurRepository.class);
        sessionService = mock(SessionService.class);
        jwtService = mock(JwtService.class);
        proprietes = mock(DogoProperties.class, RETURNS_DEEP_STUBS);

        maintenant = Instant.parse("2026-10-13T10:00:00Z");
        horloge = Clock.fixed(maintenant, ZoneId.of("UTC"));

        when(proprietes.session().inactivite()).thenReturn(Duration.ofMinutes(15));

        service = new RefreshTokenService(
                refreshTokenRepository,
                utilisateurRepository,
                sessionRepository,
                sessionService,
                jwtService,
                proprietes,
                horloge
        );
    }

    @Test
    void creerToken_creeEtSauvegardeToken() {
        when(refreshTokenRepository.save(any(RefreshToken.class))).thenAnswer(i -> i.getArgument(0));

        var res = service.creerToken(1L, 10L, "device-1", "127.0.0.1", false);

        assertNotNull(res.jetonBrut());
        assertEquals(maintenant.plus(Duration.ofDays(60)), res.expiration());
        verify(refreshTokenRepository).save(any(RefreshToken.class));
    }

    @Test
    void rafraichir_avecTokenValide_effectueRotation() {
        String rawToken = "my-secret-raw-token";
        String hash = RefreshTokenService.hacher(rawToken);

        RefreshToken existing = new RefreshToken(hash, 1L, 10L, "device-1", "127.0.0.1", maintenant.minusSeconds(3600), maintenant.plus(Duration.ofDays(30)));
        when(refreshTokenRepository.findByTokenHash(hash)).thenReturn(Optional.of(existing));

        Role role = mock(Role.class);
        when(role.getPermissions()).thenReturn(java.util.Set.of());
        Commercant commercant = new Commercant("+22370000001", "Awa", "hash", role, maintenant, "Boutique", "Bamako", "Quartier", "WHATSAPP");
        org.springframework.test.util.ReflectionTestUtils.setField(commercant, "id", 1L);
        when(utilisateurRepository.findById(1L)).thenReturn(Optional.of(commercant));

        SessionUtilisateur session = new SessionUtilisateur(1L, "device-1", "127.0.0.1", null, maintenant, maintenant.plus(Duration.ofMinutes(15)));
        when(sessionRepository.findById(10L)).thenReturn(Optional.of(session));
        when(jwtService.generer(anyLong(), anyLong(), anyString(), anyList(), any(), any())).thenReturn("new-jwt-token");

        var tokenPair = service.rafraichir(rawToken, "device-1", "127.0.0.1");

        assertNotNull(tokenPair);
        assertEquals("new-jwt-token", tokenPair.jeton());
        assertNotEquals(rawToken, tokenPair.refreshToken());
        assertTrue(existing.isRevoque());
        assertNotNull(existing.getRemplaceParHash());
        verify(refreshTokenRepository, times(2)).save(any(RefreshToken.class));
    }

    @Test
    void rafraichir_avecTokenRevoque_detecteReutilisationEtRevoqueTout() {
        String rawToken = "compromised-token";
        String hash = RefreshTokenService.hacher(rawToken);

        RefreshToken revoque = new RefreshToken(hash, 1L, 10L, "device-1", "127.0.0.1", maintenant.minusSeconds(7200), maintenant.plus(Duration.ofDays(30)));
        revoque.revoquer(maintenant.minusSeconds(3600));

        when(refreshTokenRepository.findByTokenHash(hash)).thenReturn(Optional.of(revoque));

        ErreurMetier ex = assertThrows(ErreurMetier.class, () -> service.rafraichir(rawToken, "device-1", "127.0.0.1"));
        assertTrue(ex.getMessage().contains("réutilisation de jeton"));

        verify(refreshTokenRepository).revoquerTousPourUtilisateur(eq(1L), eq(maintenant));
        verify(sessionService).invaliderToutes(1L);
    }

    @Test
    void rafraichir_avecTokenRevoqueRecemment_gracePeriodNeRevoquePasToutesSessions() {
        String rawToken = "just-rotated-token";
        String hash = RefreshTokenService.hacher(rawToken);

        RefreshToken revoque = new RefreshToken(hash, 1L, 10L, "device-1", "127.0.0.1", maintenant.minusSeconds(10), maintenant.plus(Duration.ofDays(30)));
        revoque.revoquer(maintenant.minusSeconds(5)); // révoqué il y a 5s (< 30s)

        when(refreshTokenRepository.findByTokenHash(hash)).thenReturn(Optional.of(revoque));

        ErreurMetier ex = assertThrows(ErreurMetier.class, () -> service.rafraichir(rawToken, "device-1", "127.0.0.1"));
        assertTrue(ex.getMessage().contains("renouvelé"));

        // Aucune invalidation globale de toutes les sessions
        verify(sessionService, never()).invaliderToutes(anyLong());
    }

    @Test
    void rafraichir_avecTokenExpire_echoue() {
        String rawToken = "expired-token";
        String hash = RefreshTokenService.hacher(rawToken);

        RefreshToken expire = new RefreshToken(hash, 1L, 10L, "device-1", "127.0.0.1", maintenant.minus(Duration.ofDays(90)), maintenant.minusSeconds(10));
        when(refreshTokenRepository.findByTokenHash(hash)).thenReturn(Optional.of(expire));

        ErreurMetier ex = assertThrows(ErreurMetier.class, () -> service.rafraichir(rawToken, "device-1", "127.0.0.1"));
        assertTrue(ex.getMessage().contains("expiré"));
        assertTrue(expire.isRevoque());
    }
}
