package ml.dogo.identite.application;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
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

    /** La session serveur fait foi : le jeton peut vivre longtemps, il est refusé dès que la session ne l'est plus. */
    private static final Duration DUREE_MAX_JETON = Duration.ofDays(365);

    public record Profil(long id, String type, String nom, String telephone, String photoUrl, String statut, List<String> permissions) {
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

    /** Haché factice pour dépenser le même temps de calcul quand le numéro est inconnu (pas d'énumération par le temps). */
    private final String hacheFactice;

    public AuthService(UtilisateurRepository utilisateurs, SessionUtilisateurRepository sessions,
                       CompteursAuthentification compteurs, SessionService sessionService,
                       RefreshTokenService refreshTokenService, PasswordEncoder encodeur,
                       JwtService jwt, DogoProperties proprietes, Clock horloge) {
        this.utilisateurs = utilisateurs;
        this.sessions = sessions;
        this.compteurs = compteurs;
        this.sessionService = sessionService;
        this.refreshTokenService = refreshTokenService;
        this.encodeur = encodeur;
        this.jwt = jwt;
        this.proprietes = proprietes;
        this.horloge = horloge;
        this.hacheFactice = encodeur.encode("pin-factice");
    }

    @Transactional
    public Connexion connecter(String telephoneBrut, String pin, String deviceId, String ip) {
        Instant maintenant = horloge.instant();
        String telephone = Telephone.normaliser(telephoneBrut);
        Utilisateur u = utilisateurs.findByTelephone(telephone).orElse(null);
        if (u == null) {
            encodeur.matches(pin == null ? "" : pin, hacheFactice);
            throw identifiantsInvalides();
        }
        u.verifierNonVerrouille(maintenant);
        boolean motDePasseValide = pin != null && encodeur.matches(pin, u.getMotDePasseHash());
        if (!motDePasseValide) {
            compteurs.enregistrerEchecPin(u.getId(), proprietes.pin().maxEchecs(), proprietes.pin().verrouillage(),
                    maintenant);
            throw identifiantsInvalides();
        }
        if (!u.getStatutCompte().peutSAuthentifier()) {
            throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-09", "Ce compte est suspendu ou désactivé");
        }
        if (!u.isTelephoneVerifie()) {
            throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-02",
                    "Téléphone non vérifié : saisissez le code reçu par SMS");
        }
        u.reinitialiserEchecsPin();
        utilisateurs.save(u);
        SessionUtilisateur session = sessions.save(new SessionUtilisateur(u.getId(), deviceId, ip, null, maintenant,
                maintenant.plus(proprietes.session().inactivite())));
        List<String> permissions = codesPermissions(u);

        boolean estAdmin = u instanceof Administrateur || "ADMIN".equals(u.typeActeur().name());
        Duration accessDuration = estAdmin ? RefreshTokenService.DUREE_ACCESS_ADMIN : RefreshTokenService.DUREE_ACCESS_STANDARD;
        Instant expiration = maintenant.plus(accessDuration);
        String jeton = jwt.generer(u.getId(), session.getId(), u.typeActeur().name(), permissions, maintenant, expiration);

        var nouveauRt = refreshTokenService.creerToken(u.getId(), session.getId(), deviceId, ip, estAdmin);
        return new Connexion(jeton, nouveauRt.jetonBrut(), expiration, nouveauRt.expiration(), profil(u, permissions));
    }

    @Transactional
    public void deconnecter(long sessionId) {
        refreshTokenService.revoquerPourSession(sessionId);
        sessionService.invalider(sessionId);
    }

    public static List<String> codesPermissions(Utilisateur u) {
        if (u instanceof Administrateur admin && admin.getRoleAdministratif() != null) {
            return switch (admin.getRoleAdministratif()) {
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
        return u.getRole().getPermissions().stream().map(p -> p.getCode()).sorted().toList();
    }

    public static Profil profil(Utilisateur u, List<String> permissions) {
        return new Profil(u.getId(), u.typeActeur().name(), u.getNom(), u.getTelephone(),
                u.getPhotoUrl(), u.getStatutCompte().name(), permissions);
    }

    private static ErreurMetier identifiantsInvalides() {
        return new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07", "Téléphone ou PIN incorrect");
    }
}
