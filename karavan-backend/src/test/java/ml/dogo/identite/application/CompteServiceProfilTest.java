package ml.dogo.identite.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Optional;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.persistence.Commercant;
import ml.dogo.identite.persistence.Courtier;
import ml.dogo.identite.persistence.DossierKycRepository;
import ml.dogo.identite.persistence.Grossiste;
import ml.dogo.identite.persistence.MoyenPaiementRepository;
import ml.dogo.identite.persistence.Role;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.notification.api.NotificationApi;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

class CompteServiceProfilTest {

    private UtilisateurRepository utilisateurs;
    private CompteService service;

    @BeforeEach
    void setUp() {
        utilisateurs = mock(UtilisateurRepository.class);
        when(utilisateurs.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service = new CompteService(
                utilisateurs,
                mock(MoyenPaiementRepository.class),
                mock(DossierKycRepository.class),
                mock(SessionService.class),
                mock(RefreshTokenService.class),
                mock(StockageAvatarService.class),
                mock(PasswordEncoder.class),
                mock(AuditApi.class),
                mock(NotificationApi.class)
        );
    }

    private void setId(Object entity, Long id) {
        try {
            var field = entity.getClass().getSuperclass().getDeclaredField("id");
            field.setAccessible(true);
            field.set(entity, id);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @Test
    @DisplayName("Modification du nom de boutique et coordonnées GPS pour commerçant")
    void commercantModifierBoutiqueEtCoordonnees() {
        Role role = mock(Role.class);
        when(role.getNom()).thenReturn("COMMERCANT");
        Commercant c = new Commercant("22370001122", "Moussa Diarra", "hash", role, Instant.now(),
                "Boutique Initiale", "Badalabougou", "Badala", "BOUTIQUE_PHYSIQUE");
        setId(c, 1L);
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(c));

        var req = new CompteService.CommandeModificationProfil(
                "Moussa D.", "fr", null,
                "Boutique Karavan Express", null, null, "Grand Marché Dabanani", null, null,
                12.6392, -8.0029
        );

        var profil = service.modifierProfil(1L, req);

        assertThat(c.getNom()).isEqualTo("Moussa D.");
        assertThat(c.getNomBoutique()).isEqualTo("Boutique Karavan Express");
        assertThat(c.getQuartierBamako()).isEqualTo("Grand Marché Dabanani");
        assertThat(c.getLatitude()).isEqualTo(12.6392);
        assertThat(c.getLongitude()).isEqualTo(-8.0029);

        assertThat(profil.details().get("nomBoutique")).isEqualTo("Boutique Karavan Express");
        assertThat(profil.details().get("quartierBamako")).isEqualTo("Grand Marché Dabanani");
        assertThat(profil.details().get("latitude")).isEqualTo(12.6392);
        assertThat(profil.details().get("longitude")).isEqualTo(-8.0029);
    }

    @Test
    @DisplayName("Modification de la société de transit et coordonnées GPS pour courtier")
    void courtierModifierSocieteEtCoordonnees() {
        Role role = mock(Role.class);
        when(role.getNom()).thenReturn("COURTIER");
        Courtier courtier = new Courtier("22376002233", "Aliou Traore", "hash", role, Instant.now(),
                "Transit Initial", "LIC-123", "Sogoniko");
        setId(courtier, 2L);
        when(utilisateurs.findById(2L)).thenReturn(Optional.of(courtier));

        var req = new CompteService.CommandeModificationProfil(
                null, null, null,
                null, null, "Sahel Transit & Hub", null, null, "Dépôt Zone Industrielle",
                12.6125, -7.9810
        );

        var profil = service.modifierProfil(2L, req);

        assertThat(courtier.getNomSocieteImport()).isEqualTo("Sahel Transit & Hub");
        assertThat(courtier.getAdresseDepot()).isEqualTo("Dépôt Zone Industrielle");
        assertThat(courtier.getLatitude()).isEqualTo(12.6125);
        assertThat(courtier.getLongitude()).isEqualTo(-7.9810);

        assertThat(profil.details().get("nomSocieteImport")).isEqualTo("Sahel Transit & Hub");
        assertThat(profil.details().get("adresseDepot")).isEqualTo("Dépôt Zone Industrielle");
        assertThat(profil.details().get("latitude")).isEqualTo(12.6125);
        assertThat(profil.details().get("longitude")).isEqualTo(-7.9810);
    }
}
