package ml.dogo.identite.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.RETURNS_DEEP_STUBS;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;
import ml.dogo.identite.persistence.CodeOtp;
import ml.dogo.identite.persistence.CodeOtpRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.ErreurMetier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

/** RG-02 : délai entre deux envois et plafond quotidien, comptés par numéro de téléphone. */
class OtpServiceTest {

    private static final String TELEPHONE = "+22379000000";
    private final Instant maintenant = Instant.parse("2026-10-21T10:00:00Z");

    private CodeOtpRepository otps;
    private NotificationApi notifications;
    private OtpService service;
    private Utilisateur utilisateur;

    @BeforeEach
    void preparer() {
        otps = mock(CodeOtpRepository.class);
        notifications = mock(NotificationApi.class);
        PasswordEncoder encodeur = mock(PasswordEncoder.class);
        when(encodeur.encode(anyString())).thenReturn("haché");
        DogoProperties proprietes = mock(DogoProperties.class, RETURNS_DEEP_STUBS);
        when(proprietes.otp().validite()).thenReturn(Duration.ofMinutes(2));
        service = new OtpService(otps, mock(CompteursAuthentification.class), encodeur, notifications, proprietes,
                Clock.fixed(maintenant, ZoneId.of("UTC")));
        utilisateur = mock(Utilisateur.class);
        when(utilisateur.getId()).thenReturn(7L);
        when(utilisateur.getTelephone()).thenReturn(TELEPHONE);
    }

    @Test
    void unCodeEstEnvoyeEtRattacheAuNumero() {
        when(otps.findFirstByTelephoneOrderByDateCreationDesc(TELEPHONE)).thenReturn(Optional.empty());
        when(otps.countByTelephoneAndDateCreationAfter(eq(TELEPHONE), any())).thenReturn(4L);

        String code = service.emettre(utilisateur);

        assertThat(code).hasSize(4);
        verify(otps).save(any(CodeOtp.class));
        verify(notifications).envoyerSms(eq(TELEPHONE), anyString());
    }

    @Test
    void auDelaDuPlafondQuotidienAucunSmsNEstEnvoye() {
        when(otps.findFirstByTelephoneOrderByDateCreationDesc(TELEPHONE)).thenReturn(Optional.empty());
        when(otps.countByTelephoneAndDateCreationAfter(TELEPHONE, maintenant.minus(Duration.ofHours(24))))
                .thenReturn((long) OtpService.MAX_ENVOIS_PAR_JOUR);

        assertThatThrownBy(() -> service.emettre(utilisateur))
                .isInstanceOf(ErreurMetier.class)
                .hasMessageContaining("Trop de codes");
        verify(otps, never()).save(any());
        verify(notifications, never()).envoyerSms(anyString(), anyString());
    }

    @Test
    void leDelaiEntreDeuxEnvoisVautPourLeNumeroMemeSurUnAutreCompte() {
        // Dernier code envoyé à ce numéro il y a 10 s, par exemple à une inscription abandonnée puis remplacée
        CodeOtp precedent = new CodeOtp(null, TELEPHONE, "h", maintenant.plusSeconds(110), maintenant.minusSeconds(10));
        when(otps.findFirstByTelephoneOrderByDateCreationDesc(TELEPHONE)).thenReturn(Optional.of(precedent));

        assertThatThrownBy(() -> service.emettre(utilisateur)).isInstanceOf(ErreurMetier.class);
        verify(notifications, never()).envoyerSms(anyString(), anyString());
    }
}
