package ml.dogo.identite.application;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.domain.RegleAcces;
import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.TypeActeur;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.identite.domain.Telephone;
import ml.dogo.identite.persistence.SessionUtilisateur;
import ml.dogo.identite.persistence.SessionUtilisateurRepository;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.JwtService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Authentification par téléphone + PIN (RG-07), création de la session liée à l'appareil (RG-08). */
@Service
public class AuthService {

    /** {@code motDePasseProvisoire} : RG-07b, l'application doit ouvrir le changement de mot de passe avant tout. */
    public record Profil(long id, String type, String nom, String telephone, String photoUrl, String statut,
                         List<String> permissions, boolean motDePasseProvisoire) {

        public Profil(long id, String type, String nom, String telephone, String photoUrl, String statut,
                      List<String> permissions) {
            this(id, type, nom, telephone, photoUrl, statut, permissions, false);
        }
    }

    public record Connexion(String jeton, String refreshToken, Instant expiration, Instant refreshExpiration, Profil profil) {
        public Connexion(String jeton, Instant expiration, Profil profil) {
            this(jeton, null, expiration, null, profil);
        }
    }

    private final UtilisateurRepository utilisateurs;
    private final SessionUtilisateurRepository sessions;
    private final CompteursAuthentification compteurs;
    private final SessionService sessionService;
    private final RefreshTokenService refreshTokenService;
    private final PasswordEncoder encodeur;
    private final JwtService jwt;
    private final DogoProperties proprietes;
    private final Clock horloge;
    private final OtpService otp;
    private final NotificationApi notifications;
    private final AuditApi audit;

    /** Haché factice pour dépenser le même temps de calcul quand le numéro est inconnu (pas d'énumération par le temps). */
    private final String hacheFactice;

    public AuthService(UtilisateurRepository utilisateurs, SessionUtilisateurRepository sessions,
                       CompteursAuthentification compteurs, SessionService sessionService,
                       RefreshTokenService refreshTokenService, PasswordEncoder encodeur,
                       JwtService jwt, DogoProperties proprietes, Clock horloge,
                       OtpService otp, NotificationApi notifications, AuditApi audit) {
        this.utilisateurs = utilisateurs;
        this.sessions = sessions;
        this.compteurs = compteurs;
        this.sessionService = sessionService;
        this.refreshTokenService = refreshTokenService;
        this.encodeur = encodeur;
        this.jwt = jwt;
        this.proprietes = proprietes;
        this.horloge = horloge;
        this.otp = otp;
        this.notifications = notifications;
        this.audit = audit;
        this.hacheFactice = encodeur.encode("pin-factice");
    }

    @Transactional
    public Connexion connecter(String telephoneBrut, String pin, String deviceId, String ip) {
        return connecter(telephoneBrut, pin, deviceId, ip, null);
    }

    @Transactional
    public Connexion connecter(String telephoneBrut, String pin, String deviceId, String ip, TypeActeur typeActeurAttendu) {
        Instant maintenant = horloge.instant();
        String telephone = Telephone.normaliser(telephoneBrut);
        Utilisateur u = utilisateurs.findByTelephone(telephone).orElse(null);
        if (u == null) {
            encodeur.matches(pin == null ? "" : pin, hacheFactice);
            throw compteInexistant();
        }
        if (typeActeurAttendu != null && u.typeActeur() != typeActeurAttendu) {
            encodeur.matches(pin == null ? "" : pin, hacheFactice);
            throw mauvaisEspaceRole(u.typeActeur(), typeActeurAttendu);
        }
        u.verifierNonVerrouille(maintenant);
        if (!u.hasMotDePasse()) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Ce compte a été configuré avec Google sans mot de passe classique. Veuillez vous connecter avec le bouton « Continuer avec Google », ou cliquer sur « Mot de passe oublié ? » pour en définir un.");
        }
        boolean motDePasseValide = pin != null && encodeur.matches(pin, u.getMotDePasseHash());
        if (!motDePasseValide) {
            compteurs.enregistrerEchecPin(u.getId(), proprietes.pin().maxEchecs(), proprietes.pin().verrouillage(),
                    maintenant);
            throw codeIncorrect();
        }
        if (!u.getStatutCompte().peutSAuthentifier()) {
            throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-09", "Ce compte est suspendu ou désactivé");
        }
        if (!u.isTelephoneVerifie()) {
            throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-02",
                    "Téléphone non vérifié : saisissez le code reçu par SMS");
        }
        if (!u.typeActeur().exigeKyc() && u.getStatutCompte() == StatutCompte.EN_ATTENTE) {
            u.changerStatut(StatutCompte.ACTIF);
        }
        u.reinitialiserEchecsPin();
        utilisateurs.save(u);
        SessionUtilisateur session = sessions.save(new SessionUtilisateur(u.getId(), deviceId, ip, null, maintenant,
                maintenant.plus(proprietes.session().inactivite())));
        List<String> permissions = codesPermissions(u);

        boolean estAdmin = u instanceof Administrateur;
        Duration accessDuration = estAdmin ? RefreshTokenService.DUREE_ACCESS_ADMIN : RefreshTokenService.DUREE_ACCESS_STANDARD;
        Instant expiration = maintenant.plus(accessDuration);
        String jeton = jwt.generer(u.getId(), session.getId(), u.typeActeur().name(), permissions, maintenant, expiration);

        var nouveauRt = refreshTokenService.creerToken(u.getId(), session.getId(), deviceId, ip, estAdmin);
        return new Connexion(jeton, nouveauRt.jetonBrut(), expiration, nouveauRt.expiration(), profil(u, permissions));
    }

    @Transactional
    public InscriptionService.Resultat demanderReinitialisationMotDePasse(String telephoneBrut) {
        return demanderReinitialisationMotDePasse(telephoneBrut, null);
    }

    @Transactional
    public InscriptionService.Resultat demanderReinitialisationMotDePasse(String telephoneBrut, TypeActeur typeActeurAttendu) {
        String telephone = Telephone.normaliser(telephoneBrut);
        Utilisateur u = utilisateurs.findByTelephone(telephone)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.COMPTE_INEXISTANT, "RG-07",
                        "Aucun compte n'est associé à ce numéro de téléphone."));
        if (typeActeurAttendu != null && u.typeActeur() != typeActeurAttendu) {
            throw mauvaisEspaceRole(u.typeActeur(), typeActeurAttendu);
        }
        if (!u.isTelephoneVerifie()) {
            throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-02",
                    "Ce numéro n'a pas encore validé son inscription.");
        }
        String code = otp.emettre(u);
        return new InscriptionService.Resultat(u.getId(), u.getStatutCompte().name(),
                proprietes.otp().afficherDansReponse() ? code : null);
    }

    @Transactional
    public void reinitialiserMotDePasseParOtp(String telephoneBrut, String codeOtp, String nouveauMotDePasse) {
        reinitialiserMotDePasseParOtp(telephoneBrut, codeOtp, nouveauMotDePasse, null);
    }

    @Transactional
    public void reinitialiserMotDePasseParOtp(String telephoneBrut, String codeOtp, String nouveauMotDePasse, TypeActeur typeActeurAttendu) {
        String telephone = Telephone.normaliser(telephoneBrut);
        Utilisateur u = utilisateurs.findByTelephone(telephone)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.COMPTE_INEXISTANT, "RG-07",
                        "Aucun compte n'est associé à ce numéro de téléphone."));
        if (typeActeurAttendu != null && u.typeActeur() != typeActeurAttendu) {
            throw mauvaisEspaceRole(u.typeActeur(), typeActeurAttendu);
        }
        otp.verifier(u.getId(), codeOtp);
        RegleAcces.verifierFormatMotDePasse(nouveauMotDePasse);
        u.changerMotDePasse(encodeur.encode(nouveauMotDePasse));
        u.reinitialiserEchecsPin();
        utilisateurs.save(u);
        sessionService.invaliderToutes(u.getId());
        refreshTokenService.revoquerPourUtilisateur(u.getId());
        audit.tracer(u.getId(), "MOT_DE_PASSE_REINITIALISE_OTP", "telephone=" + telephone, null);
        notifications.envoyerSms(telephone, "DoGo : Votre mot de passe a été réinitialisé avec succès.");
    }

    @Transactional
    public void deconnecter(long sessionId) {
        refreshTokenService.revoquerPourSession(sessionId);
        sessionService.invalider(sessionId);
    }

    public static List<String> codesPermissions(Utilisateur u) {
        if (u instanceof Administrateur admin && admin.getRoleAdministratif() != null) {
            return permissionsAdministratives(admin.getRoleAdministratif());
        }
        return u.getRole().getPermissions().stream().map(p -> p.getCode()).sorted().toList();
    }

    /** Ce que chaque fonction administrative permet de faire (RG-06) : source unique, aussi affichée dans la console. */
    public static List<String> permissionsAdministratives(RoleAdministratif role) {
        return switch (role) {
            case TECHNIQUE -> List.of("ADMIN_CREER", "AUDIT_LIRE", "CAMPAGNE_EXPLORER", "COMMANDE_AVANCER", "COMMANDE_LIRE", "COMPTE_SUSPENDRE",
                    "GROUPE_ANNULER", "GROUPE_CREER", "GROUPE_DISPONIBILITE_VALIDER", "GROUPE_PUBLICATION_VALIDER", "GROUPE_SUIVRE", "KYC_VALIDER", "NOTIFICATION_LIRE",
                    "POINT_RETRAIT_GERER", "PORTEFEUILLE_RETIRER", "PROFIL_GERER", "RECEPTION_VALIDER", "REMBOURSEMENT_APPROUVER", "RETRAIT_VALIDER");
            case VALIDATION -> List.of("CAMPAGNE_EXPLORER", "GROUPE_ANNULER", "GROUPE_PUBLICATION_VALIDER", "GROUPE_SUIVRE", "KYC_VALIDER", "NOTIFICATION_LIRE", "PROFIL_GERER");
            case FINANCE -> List.of("CAMPAGNE_EXPLORER", "GROUPE_SUIVRE", "NOTIFICATION_LIRE", "PORTEFEUILLE_RETIRER", "PROFIL_GERER", "REMBOURSEMENT_APPROUVER");
            case SUPPORT -> List.of("CAMPAGNE_EXPLORER", "COMMANDE_LIRE", "COMPTE_SUSPENDRE", "GROUPE_SUIVRE", "NOTIFICATION_LIRE", "PROFIL_GERER");
            case LOGISTIQUE -> List.of("CAMPAGNE_EXPLORER", "COMMANDE_AVANCER", "COMMANDE_LIRE", "GROUPE_SUIVRE", "NOTIFICATION_LIRE",
                    "POINT_RETRAIT_GERER", "PROFIL_GERER", "RECEPTION_VALIDER", "RETRAIT_VALIDER");
        };
    }

    public static Profil profil(Utilisateur u, List<String> permissions) {
        return new Profil(u.getId(), u.typeActeur().name(), u.getNom(), u.getTelephone(),
                u.getPhotoUrl(), u.getStatutCompte().name(), permissions, u.isMotDePasseProvisoire());
    }

    public static String libelleRole(TypeActeur type) {
        return type == null ? "Utilisateur" : type.libelle();
    }

    public static ErreurMetier mauvaisEspaceRole(TypeActeur roleReel, TypeActeur roleAttendu) {
        return new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-01",
                "Ce compte est enregistré dans l'espace " + libelleRole(roleReel)
                        + " et ne peut pas être utilisé dans l'espace " + libelleRole(roleAttendu) + ".");
    }

    private static ErreurMetier compteInexistant() {
        return new ErreurMetier(CodeErreur.COMPTE_INEXISTANT, "RG-07",
                "Aucun compte n'est associé à ce numéro de téléphone. Souhaitez-vous créer un compte ?");
    }

    private static ErreurMetier codeIncorrect() {
        return new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                "Mot de passe ou code secret incorrect. Veuillez vérifier votre saisie et réessayer.");
    }
}
