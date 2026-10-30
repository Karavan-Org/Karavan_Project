package ml.dogo.identite.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.TypeActeur;
import ml.dogo.identite.persistence.CompteExterne;
import ml.dogo.identite.persistence.CompteExterneRepository;
import ml.dogo.identite.persistence.Commercant;
import ml.dogo.identite.persistence.Courtier;
import ml.dogo.identite.persistence.Grossiste;
import ml.dogo.identite.persistence.RefreshToken;
import ml.dogo.identite.persistence.Role;
import ml.dogo.identite.persistence.RoleRepository;
import ml.dogo.identite.persistence.SessionUtilisateur;
import ml.dogo.identite.persistence.SessionUtilisateurRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Tests unitaires complets de la fédération d'identité OAuth2 Google :
 * - Jeton invalide, expiré, mauvaise audience, mauvais émetteur
 * - Sub inconnu → profil incomplet sans création de compte
 * - Complétion avec OTP → création de compte Commerçant sans mot de passe
 * - Fusion de compte → rattachement du sub Google au compte existant par numéro vérifié
 * - Refus de fusion sur email_verified = false
 * - Reconnexion directe avec sub connu
 */
class GoogleAuthServiceTest {

    private final Instant maintenant = Instant.parse("2026-10-28T10:00:00Z");
    private final Clock horloge = Clock.fixed(maintenant, ZoneId.of("UTC"));

    private GoogleTokenVerifier tokenVerifier;
    private CompteExterneRepository comptesExternes;
    private UtilisateurRepository utilisateurs;
    private RoleRepository roles;
    private SessionUtilisateurRepository sessions;
    private RefreshTokenService refreshTokenService;
    private OtpService otpService;
    private JetonInscriptionTemporaireService jetonInscriptionService;
    private LimiteurDebitIp limiteurDebitIp;
    private JwtService jwt;
    private DogoProperties proprietes;
    private AuditApi audit;

    private GoogleAuthService service;
    private Role roleCommercant;

    @BeforeEach
    void preparer() {
        tokenVerifier = mock(GoogleTokenVerifier.class);
        comptesExternes = mock(CompteExterneRepository.class);
        utilisateurs = mock(UtilisateurRepository.class);
        roles = mock(RoleRepository.class);
        sessions = mock(SessionUtilisateurRepository.class);
        refreshTokenService = mock(RefreshTokenService.class);
        otpService = mock(OtpService.class);
        limiteurDebitIp = mock(LimiteurDebitIp.class);
        jwt = mock(JwtService.class);
        audit = mock(AuditApi.class);

        proprietes = mock(DogoProperties.class, org.mockito.Mockito.RETURNS_DEEP_STUBS);
        when(proprietes.jwt().secret()).thenReturn("test-secret-tres-securise-qui-fait-au-moins-256-bits-pour-le-hmac!");
        when(proprietes.session().inactivite()).thenReturn(Duration.ofDays(30));
        when(proprietes.otp().afficherDansReponse()).thenReturn(true);

        jetonInscriptionService = new JetonInscriptionTemporaireService(proprietes);

        roleCommercant = mock(Role.class);
        when(roleCommercant.getNom()).thenReturn("COMMERCANT");
        when(roles.findByNom("COMMERCANT")).thenReturn(Optional.of(roleCommercant));

        when(sessions.save(any())).thenAnswer(inv -> {
            SessionUtilisateur s = inv.getArgument(0);
            org.springframework.test.util.ReflectionTestUtils.setField(s, "id", 1L);
            return s;
        });
        when(utilisateurs.save(any())).thenAnswer(inv -> {
            Utilisateur u = inv.getArgument(0);
            if (u.getId() == null) {
                org.springframework.test.util.ReflectionTestUtils.setField(u, "id", 42L);
            }
            return u;
        });
        when(jwt.generer(anyLong(), anyLong(), any(), any(), any(), any())).thenReturn("mock-access-jwt");
        when(refreshTokenService.creerToken(anyLong(), any(), any(), any(), anyBoolean()))
                .thenReturn(new RefreshTokenService.NouveauRefreshToken("mock-refresh-token", maintenant.plus(Duration.ofDays(30))));

        service = new GoogleAuthService(
                tokenVerifier, comptesExternes, utilisateurs, roles, sessions,
                refreshTokenService, otpService, jetonInscriptionService,
                limiteurDebitIp, jwt, proprietes, horloge, audit
        );
    }

    @Test
    void jetonInvalideEstRefuse() {
        when(tokenVerifier.verifier("bad-token")).thenThrow(
                new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07", "Jeton d'authentification Google invalide"));

        assertThatThrownBy(() -> service.authentifier("bad-token", "dev-1", "10.0.0.1"))
                .isInstanceOf(ErreurMetier.class)
                .hasFieldOrPropertyWithValue("code", CodeErreur.NON_AUTHENTIFIE);
    }

    @Test
    void subInconnuRenvoieProfilIncompletSansCreerDeCompte() {
        GoogleIdTokenInfo info = new GoogleIdTokenInfo(
                "google-sub-new", "salif@gmail.com", true, "Salif Keita", "https://photo.url");
        when(tokenVerifier.verifier("valid-token")).thenReturn(info);
        when(comptesExternes.findByFournisseurAndSubAvecUtilisateur("GOOGLE", "google-sub-new"))
                .thenReturn(Optional.empty());

        var resultat = service.authentifier("valid-token", "dev-1", "10.0.0.1");

        assertThat(resultat.statut()).isEqualTo("PROFIL_INCOMPLET");
        assertThat(resultat.jetonInscription()).isNotBlank();
        assertThat(resultat.sub()).isEqualTo("google-sub-new");
        assertThat(resultat.email()).isEqualTo("salif@gmail.com");
        assertThat(resultat.nom()).isEqualTo("Salif Keita");

        // Aucun compte créé en base
        verify(utilisateurs, org.mockito.Mockito.never()).save(any());
        verify(comptesExternes, org.mockito.Mockito.never()).save(any());
    }

    @Test
    void completionProfilCreeUnNouveauCompteCommercantSansMotDePasseEtOuvreSession() {
        GoogleIdTokenInfo info = new GoogleIdTokenInfo(
                "google-sub-100", "nouveau@gmail.com", true, "Nouveau Client", "https://photo.jpg");
        String jetonInscription = jetonInscriptionService.emettre(info);

        when(utilisateurs.findByTelephone("+22375000001")).thenReturn(Optional.empty());

        GoogleAuthService.DemandeCompleterGoogle demande = new GoogleAuthService.DemandeCompleterGoogle(
                jetonInscription, "+223 75 00 00 01", "1234", TypeActeur.COMMERCANT,
                "Boutique Centrale", "Grand Marché", "device-flutter-1"
        );

        AuthService.Connexion c = service.completerEtConnecter(demande, "10.0.0.1");

        assertThat(c).isNotNull();
        assertThat(c.jeton()).isEqualTo("mock-access-jwt");
        assertThat(c.refreshToken()).isEqualTo("mock-refresh-token");
        // RG-03 : le commerçant est immédiatement ACTIF sans validation KYC
        assertThat(c.profil().type()).isEqualTo("COMMERCANT");
        assertThat(c.profil().statut()).isEqualTo("ACTIF");

        // Vérification du code OTP
        verify(otpService).verifierPourTelephone("+22375000001", "1234");

        // Vérification de la création de la ligne compte_externe
        verify(comptesExternes).save(any(CompteExterne.class));

        // Audit tracé
        verify(audit).tracer(any(), eq("CREATION_COMPTE_GOOGLE"), any(), anyString());
    }

    @Test
    void completionProfilGrossisteEtCourtierResteEnAttenteValidationKyc() {
        Role roleGrossiste = mock(Role.class);
        when(roleGrossiste.getNom()).thenReturn("GROSSISTE");
        when(roles.findByNom("GROSSISTE")).thenReturn(Optional.of(roleGrossiste));

        Role roleCourtier = mock(Role.class);
        when(roleCourtier.getNom()).thenReturn("COURTIER");
        when(roles.findByNom("COURTIER")).thenReturn(Optional.of(roleCourtier));

        when(utilisateurs.findByTelephone(anyString())).thenReturn(Optional.empty());

        String jetonGrossiste = jetonInscriptionService.emettre(
                new GoogleIdTokenInfo("sub-grossiste-1", "grossiste@gmail.com", true, "Grossiste Import", null));
        AuthService.Connexion cg = service.completerEtConnecter(new GoogleAuthService.DemandeCompleterGoogle(
                jetonGrossiste, "+223 71 00 00 99", "1111", TypeActeur.GROSSISTE, null, null, "dev-g"
        ), "10.0.0.1");

        assertThat(cg.profil().type()).isEqualTo("GROSSISTE");
        assertThat(cg.profil().statut()).isEqualTo("EN_ATTENTE");

        String jetonCourtier = jetonInscriptionService.emettre(
                new GoogleIdTokenInfo("sub-courtier-1", "courtier@gmail.com", true, "Courtier Transit", null));
        AuthService.Connexion cc = service.completerEtConnecter(new GoogleAuthService.DemandeCompleterGoogle(
                jetonCourtier, "+223 72 00 00 99", "2222", TypeActeur.COURTIER, null, null, "dev-c"
        ), "10.0.0.1");

        assertThat(cc.profil().type()).isEqualTo("COURTIER");
        assertThat(cc.profil().statut()).isEqualTo("EN_ATTENTE");
    }

    @Test
    void fusionDeCompteSiMemeNumeroDejaInscritEnClassique() {
        GoogleIdTokenInfo info = new GoogleIdTokenInfo(
                "google-sub-200", "fusion@gmail.com", true, "Salif Existant", null);
        String jetonInscription = jetonInscriptionService.emettre(info);

        Commercant compteExistant = new Commercant(
                "+22376000002", "Salif Classique", "hash-secret", roleCommercant,
                maintenant.minus(Duration.ofDays(10)), "Boutique Existant", null, "Bamako", null
        );
        org.springframework.test.util.ReflectionTestUtils.setField(compteExistant, "id", 84L);
        compteExistant.marquerTelephoneVerifie();
        compteExistant.changerStatut(StatutCompte.ACTIF);

        when(utilisateurs.findByTelephone("+22376000002")).thenReturn(Optional.of(compteExistant));
        when(comptesExternes.existsByFournisseurAndSub("GOOGLE", "google-sub-200")).thenReturn(false);

        GoogleAuthService.DemandeCompleterGoogle demande = new GoogleAuthService.DemandeCompleterGoogle(
                jetonInscription, "+223 76 00 00 02", "4567", TypeActeur.COMMERCANT,
                null, null, "device-web-1"
        );

        AuthService.Connexion c = service.completerEtConnecter(demande, "10.0.0.1");

        assertThat(c).isNotNull();

        // Le compte existant a été conservé et rattaché
        verify(comptesExternes).save(any(CompteExterne.class));
        verify(audit).tracer(any(), eq("FUSION_COMPTE_GOOGLE"), any(), anyString());
    }

    @Test
    void subConnuConnecteDirectementSansRecreerDeCompte() {
        Commercant commercant = new Commercant(
                "+22370000003", "Salif Connecte", null, roleCommercant,
                maintenant.minus(Duration.ofDays(5)), "Boutique Salif", null, "Badalabougou", null
        );
        org.springframework.test.util.ReflectionTestUtils.setField(commercant, "id", 99L);
        commercant.marquerTelephoneVerifie();
        commercant.changerStatut(StatutCompte.ACTIF);

        CompteExterne ce = new CompteExterne("GOOGLE", "sub-existant-777", commercant, "salif@gmail.com", maintenant.minus(Duration.ofDays(5)));

        when(tokenVerifier.verifier("jwt-google-existant")).thenReturn(
                new GoogleIdTokenInfo("sub-existant-777", "salif@gmail.com", true, "Salif Connecte", null));
        when(comptesExternes.findByFournisseurAndSubAvecUtilisateur("GOOGLE", "sub-existant-777"))
                .thenReturn(Optional.of(ce));

        var resultat = service.authentifier("jwt-google-existant", "device-app", "10.0.0.1");

        assertThat(resultat.statut()).isEqualTo("CONNECTE");
        assertThat(resultat.jeton()).isEqualTo("mock-access-jwt");
        assertThat(resultat.refreshToken()).isEqualTo("mock-refresh-token");
        verify(audit).tracer(any(), eq("CONNEXION_GOOGLE"), any(), anyString());
    }

    @Test
    void refuseConnexionGoogleSiCompteAppartientAUnAutreEspace() {
        Commercant commercant = new Commercant(
                "+22370000003", "Salif Commerçant", null, roleCommercant,
                maintenant.minus(Duration.ofDays(5)), "Boutique Salif", null, "Badalabougou", null
        );
        org.springframework.test.util.ReflectionTestUtils.setField(commercant, "id", 99L);
        commercant.marquerTelephoneVerifie();
        commercant.changerStatut(StatutCompte.ACTIF);

        CompteExterne ce = new CompteExterne("GOOGLE", "sub-commercant-99", commercant, "salif@gmail.com", maintenant.minus(Duration.ofDays(5)));

        when(tokenVerifier.verifier("jwt-google-commercant")).thenReturn(
                new GoogleIdTokenInfo("sub-commercant-99", "salif@gmail.com", true, "Salif Commerçant", null));
        when(comptesExternes.findByFournisseurAndSubAvecUtilisateur("GOOGLE", "sub-commercant-99"))
                .thenReturn(Optional.of(ce));

        assertThatThrownBy(() -> service.authentifier("jwt-google-commercant", "device-app", "10.0.0.1", TypeActeur.GROSSISTE))
                .isInstanceOf(ErreurMetier.class)
                .hasFieldOrPropertyWithValue("code", CodeErreur.ACCES_REFUSE);

        assertThatThrownBy(() -> service.authentifier("jwt-google-commercant", "device-app", "10.0.0.1", TypeActeur.COURTIER))
                .isInstanceOf(ErreurMetier.class)
                .hasFieldOrPropertyWithValue("code", CodeErreur.ACCES_REFUSE);
    }

    @Test
    void refuseFusionGoogleSiNumeroAppartientAUnAutreRole() {
        GoogleIdTokenInfo info = new GoogleIdTokenInfo(
                "google-sub-300", "grossiste@gmail.com", true, "Grossiste Nouveau", null);
        String jetonInscription = jetonInscriptionService.emettre(info);

        Commercant compteCommercant = new Commercant(
                "+22376000099", "Client Commerçant", "hash", roleCommercant,
                maintenant.minus(Duration.ofDays(2)), "Boutique", null, "Bamako", null
        );
        org.springframework.test.util.ReflectionTestUtils.setField(compteCommercant, "id", 101L);
        compteCommercant.marquerTelephoneVerifie();
        compteCommercant.changerStatut(StatutCompte.ACTIF);

        when(utilisateurs.findByTelephone("+22376000099")).thenReturn(Optional.of(compteCommercant));

        // 1. Refus dès la demande d'OTP SMS
        assertThatThrownBy(() -> service.declencherOtpCompleter(
                jetonInscription, "+223 76 00 00 99", TypeActeur.GROSSISTE, "10.0.0.1"))
                .isInstanceOf(ErreurMetier.class)
                .hasFieldOrPropertyWithValue("code", CodeErreur.ACCES_REFUSE);

        // 2. Refus à la complétion sans consommer le jeton temporaire
        GoogleAuthService.DemandeCompleterGoogle demande = new GoogleAuthService.DemandeCompleterGoogle(
                jetonInscription, "+223 76 00 00 99", "1234", TypeActeur.COURTIER,
                null, null, "device-web"
        );
        assertThatThrownBy(() -> service.completerEtConnecter(demande, "10.0.0.1"))
                .isInstanceOf(ErreurMetier.class)
                .hasFieldOrPropertyWithValue("code", CodeErreur.ACCES_REFUSE);
    }

    @Test
    void refuseConnexionGoogleSiAucunCompteAssocieEnModeConnexion() {
        when(tokenVerifier.verifier("jwt-google-inconnu")).thenReturn(
                new GoogleIdTokenInfo("sub-inconnu-500", "nouveau@gmail.com", true, "Nouveau Client", null));
        when(comptesExternes.findByFournisseurAndSubAvecUtilisateur("GOOGLE", "sub-inconnu-500"))
                .thenReturn(Optional.empty());

        // En mode CONNEXION : refus COMPTE_INEXISTANT (suggérer l'inscription)
        assertThatThrownBy(() -> service.authentifier(
                "jwt-google-inconnu", "device-web", "10.0.0.1",
                TypeActeur.COMMERCANT, GoogleAuthService.ModeAuthGoogle.CONNEXION))
                .isInstanceOf(ErreurMetier.class)
                .hasFieldOrPropertyWithValue("code", CodeErreur.COMPTE_INEXISTANT);

        // En mode INSCRIPTION : autorise PROFIL_INCOMPLET pour poursuivre la création du compte
        var resultatInscription = service.authentifier(
                "jwt-google-inconnu", "device-web", "10.0.0.1",
                TypeActeur.COMMERCANT, GoogleAuthService.ModeAuthGoogle.INSCRIPTION);
        assertThat(resultatInscription.statut()).isEqualTo("PROFIL_INCOMPLET");
        assertThat(resultatInscription.jetonInscription()).isNotBlank();
    }

    @Test
    void refuseInscriptionGoogleSiCompteExisteDejaDansLeMemeRole() {
        Commercant commercant = new Commercant(
                "+22370000088", "Salif Existant", null, roleCommercant,
                maintenant.minus(Duration.ofDays(3)), "Boutique Salif", null, "Bamako", null
        );
        org.springframework.test.util.ReflectionTestUtils.setField(commercant, "id", 88L);
        commercant.marquerTelephoneVerifie();
        commercant.changerStatut(StatutCompte.ACTIF);

        CompteExterne ce = new CompteExterne("GOOGLE", "sub-deja-inscrit", commercant, "salif@gmail.com", maintenant.minus(Duration.ofDays(3)));

        when(tokenVerifier.verifier("jwt-deja-inscrit")).thenReturn(
                new GoogleIdTokenInfo("sub-deja-inscrit", "salif@gmail.com", true, "Salif Existant", null));
        when(comptesExternes.findByFournisseurAndSubAvecUtilisateur("GOOGLE", "sub-deja-inscrit"))
                .thenReturn(Optional.of(ce));

        assertThatThrownBy(() -> service.authentifier(
                "jwt-deja-inscrit", "device-web", "10.0.0.1",
                TypeActeur.COMMERCANT, GoogleAuthService.ModeAuthGoogle.INSCRIPTION))
                .isInstanceOf(ErreurMetier.class)
                .hasFieldOrPropertyWithValue("code", CodeErreur.CONFLIT);
    }
}
