package ml.dogo.identite.application;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import ml.dogo.identite.domain.Telephone;
import ml.dogo.identite.persistence.SessionUtilisateur;
import ml.dogo.identite.persistence.SessionUtilisateurRepository;
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

    public record Profil(long id, String type, String nom, String telephone, String statut, List<String> permissions) {
    }

    public record Connexion(String jeton, Instant expiration, Profil profil) {
    }

    private final UtilisateurRepository utilisateurs;
    private final SessionUtilisateurRepository sessions;
    private final CompteursAuthentification compteurs;
    private final SessionService sessionService;
    private final PasswordEncoder encodeur;
    private final JwtService jwt;
    private final DogoProperties proprietes;
    private final Clock horloge;

    /** Haché factice pour dépenser le même temps de calcul quand le numéro est inconnu (pas d'énumération par le temps). */
    private final String hacheFactice;

    public AuthService(UtilisateurRepository utilisateurs, SessionUtilisateurRepository sessions,
                       CompteursAuthentification compteurs, SessionService sessionService, PasswordEncoder encodeur,
                       JwtService jwt, DogoProperties proprietes, Clock horloge) {
        this.utilisateurs = utilisateurs;
        this.sessions = sessions;
        this.compteurs = compteurs;
        this.sessionService = sessionService;
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
        if (pin == null || !encodeur.matches(pin, u.getPinHash())) {
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
        SessionUtilisateur session = sessions.save(new SessionUtilisateur(u.getId(), deviceId, ip, null, maintenant,
                maintenant.plus(proprietes.session().inactivite())));
        List<String> permissions = codesPermissions(u);
        Instant expiration = maintenant.plus(DUREE_MAX_JETON);
        String jeton = jwt.generer(u.getId(), session.getId(), u.typeActeur().name(), permissions, maintenant, expiration);
        return new Connexion(jeton, expiration, profil(u, permissions));
    }

    @Transactional
    public void deconnecter(long sessionId) {
        sessionService.invalider(sessionId);
    }

    private static List<String> codesPermissions(Utilisateur u) {
        return u.getRole().getPermissions().stream().map(p -> p.getCode()).sorted().toList();
    }

    private static Profil profil(Utilisateur u, List<String> permissions) {
        return new Profil(u.getId(), u.typeActeur().name(), u.getNom(), u.getTelephone(),
                u.getStatutCompte().name(), permissions);
    }

    private static ErreurMetier identifiantsInvalides() {
        return new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07", "Téléphone ou PIN incorrect");
    }
}
