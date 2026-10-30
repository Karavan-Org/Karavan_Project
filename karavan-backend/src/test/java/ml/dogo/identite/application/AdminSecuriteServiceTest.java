package ml.dogo.identite.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.Role;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminSecuriteServiceTest {

    @Mock
    private UtilisateurRepository utilisateurs;

    @Mock
    private AuditApi audit;

    private PasswordEncoder encodeur;
    private Clock horloge;
    private AdminSecuriteService service;
    private Administrateur admin;

    @BeforeEach
    void setup() {
        encodeur = new BCryptPasswordEncoder();
        horloge = Clock.fixed(Instant.parse("2026-10-28T12:00:00Z"), ZoneId.of("UTC"));
        service = new AdminSecuriteService(utilisateurs, encodeur, audit, horloge);

        Role roleAdmin = org.mockito.Mockito.mock(Role.class);
        admin = new Administrateur("+22370000001", "Admin Test", encodeur.encode("Dogo2026!"),
                roleAdmin, horloge.instant(), "ADM-TEST", RoleAdministratif.TECHNIQUE);
    }

    @Test
    void statut_initialement_non_configure() {
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));

        var statut = service.obtenirStatut(1L);
        assertFalse(statut.configure());
        assertEquals("ADM-TEST", statut.matricule());
    }

    @Test
    void configurer_premier_code_succes() {
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));
        when(utilisateurs.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.configurerCode(1L, "4821", "1234");

        assertTrue(admin.hasCodeSecurite());
        assertNotNull(admin.getCodeSecuriteDate());
        assertTrue(encodeur.matches("4821", admin.getCodeSecuriteHash()));
        verify(audit).tracer(1L, "CODE_SECURITE_ADMIN_CONFIGURE", null, "Code de sécurité à 4 chiffres configuré avec succès");
    }

    @Test
    void premier_parametrage_exige_le_code_provisoire() {
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));

        assertEquals(CodeErreur.CODE_SECURITE_INVALIDE,
                assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "4821", null)).code());
        assertEquals(CodeErreur.CODE_SECURITE_INVALIDE,
                assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "4821", "0000")).code());
        assertFalse(admin.hasCodeSecurite());
    }

    @Test
    void code_provisoire_jamais_conserve_comme_code_personnel() {
        ErreurMetier err = assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "1234", "1234"));
        assertEquals(CodeErreur.DONNEES_INVALIDES, err.code());
        assertEquals("RG-SEC-03", err.regle());
    }

    @Test
    void nouveau_code_doit_differer_du_code_actuel() {
        admin.definirCodeSecurite(encodeur.encode("4821"), horloge.instant());
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));

        ErreurMetier err = assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "4821", "4821"));
        assertEquals(CodeErreur.DONNEES_INVALIDES, err.code());
    }

    @Test
    void code_provisoire_ne_valide_aucune_action() {
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));

        assertThrows(ErreurMetier.class, () -> service.verifierCode(1L, "1234"));
    }

    @Test
    void format_invalide_refuse() {
        ErreurMetier err1 = assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "123", null));
        assertEquals(CodeErreur.DONNEES_INVALIDES, err1.code());

        ErreurMetier err2 = assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "12345", null));
        assertEquals(CodeErreur.DONNEES_INVALIDES, err2.code());

        ErreurMetier err3 = assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "abcd", null));
        assertEquals(CodeErreur.DONNEES_INVALIDES, err3.code());
    }

    @Test
    void modifier_code_exige_ancien_code_valide() {
        admin.definirCodeSecurite(encodeur.encode("4821"), horloge.instant());
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));

        // Sans ancien code
        assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "9999", null));

        // Avec mauvais ancien code
        ErreurMetier errMauvais = assertThrows(ErreurMetier.class, () -> service.configurerCode(1L, "9999", "0000"));
        assertEquals(CodeErreur.CODE_SECURITE_INVALIDE, errMauvais.code());

        // Avec bon ancien code
        when(utilisateurs.save(any())).thenAnswer(inv -> inv.getArgument(0));
        service.configurerCode(1L, "9999", "4821");
        assertTrue(encodeur.matches("9999", admin.getCodeSecuriteHash()));
    }

    @Test
    void verifier_code_succes_et_echec() {
        admin.definirCodeSecurite(encodeur.encode("7391"), horloge.instant());
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));

        // Bon code
        service.verifierCode(1L, "7391");
        verify(audit).tracer(1L, "CODE_SECURITE_VALIDE", null, "Validation sécurisée par code à 4 chiffres");

        // Mauvais code
        ErreurMetier err = assertThrows(ErreurMetier.class, () -> service.verifierCode(1L, "1111"));
        assertEquals(CodeErreur.CODE_SECURITE_INVALIDE, err.code());
    }

    @Test
    void verifier_code_refuse_si_non_configure() {
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));

        ErreurMetier err = assertThrows(ErreurMetier.class, () -> service.verifierCode(1L, "1234"));
        assertEquals(CodeErreur.ACCES_REFUSE, err.code());
    }

    @Test
    void code_oublie_redefini_avec_mot_de_passe_de_connexion() {
        admin.definirCodeSecurite(encodeur.encode("1111"), horloge.instant());
        when(utilisateurs.findById(1L)).thenReturn(Optional.of(admin));

        ErreurMetier err = assertThrows(ErreurMetier.class,
                () -> service.configurerCode(1L, "2222", null, "MauvaisMdp"));
        assertEquals(CodeErreur.CODE_SECURITE_INVALIDE, err.code());
        assertTrue(encodeur.matches("1111", admin.getCodeSecuriteHash()));

        when(utilisateurs.save(any())).thenAnswer(inv -> inv.getArgument(0));
        service.configurerCode(1L, "2222", null, "Dogo2026!");
        assertTrue(encodeur.matches("2222", admin.getCodeSecuriteHash()));
    }
}
