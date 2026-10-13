package ml.dogo.identite.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.RefreshToken;
import ml.dogo.identite.persistence.RefreshTokenRepository;
import ml.dogo.identite.persistence.SessionUtilisateur;
import ml.dogo.identite.persistence.SessionUtilisateurRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.JwtService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gestion du cycle de vie des refresh tokens : émission, rotation glissante, détection de réutilisation
 * et révocation (RG-07, RG-08).
 */
@Service
public class RefreshTokenService {

    public static final Duration DUREE_ACCESS_STANDARD = Duration.ofMinutes(30);
    public static final Duration DUREE_ACCESS_ADMIN = Duration.ofMinutes(15);
    public static final Duration DUREE_REFRESH_STANDARD = Duration.ofDays(60);
    public static final Duration DUREE_REFRESH_ADMIN = Duration.ofDays(7);

    public record TokenPair(
            String jeton,
            String refreshToken,
            Instant expiration,
            Instant refreshExpiration,
            AuthService.Profil profil
    ) {}

    public record NouveauRefreshToken(
            String jetonBrut,
            Instant expiration
    ) {}

    private final RefreshTokenRepository refreshTokenRepository;
    private final UtilisateurRepository utilisateurRepository;
    private final SessionUtilisateurRepository sessionRepository;
    private final SessionService sessionService;
    private final JwtService jwtService;
    private final DogoProperties proprietes;
    private final Clock horloge;
    private final SecureRandom secureRandom = new SecureRandom();

    public RefreshTokenService(
            RefreshTokenRepository refreshTokenRepository,
            UtilisateurRepository utilisateurRepository,
            SessionUtilisateurRepository sessionRepository,
            SessionService sessionService,
            JwtService jwtService,
            DogoProperties proprietes,
            Clock horloge
    ) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.utilisateurRepository = utilisateurRepository;
        this.sessionRepository = sessionRepository;
        this.sessionService = sessionService;
        this.jwtService = jwtService;
        this.proprietes = proprietes;
        this.horloge = horloge;
    }

    @Transactional
    public NouveauRefreshToken creerToken(long utilisateurId, Long sessionId, String deviceId, String ip, boolean estAdmin) {
        Instant maintenant = horloge.instant();
        Duration duree = estAdmin ? DUREE_REFRESH_ADMIN : DUREE_REFRESH_STANDARD;
        Instant expiration = maintenant.plus(duree);
        String jetonBrut = genererAleatoire();
        String hash = hacher(jetonBrut);

        RefreshToken token = new RefreshToken(
                hash, utilisateurId, sessionId, deviceId, ip, maintenant, expiration
        );
        refreshTokenRepository.save(token);
        return new NouveauRefreshToken(jetonBrut, expiration);
    }

    @Transactional
    public TokenPair rafraichir(String jetonBrut, String deviceId, String ip) {
        if (jetonBrut == null || jetonBrut.isBlank()) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07", "Jeton de rafraîchissement absent");
        }
        Instant maintenant = horloge.instant();
        String hash = hacher(jetonBrut.trim());
        RefreshToken token = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07", "Jeton de rafraîchissement introuvable ou invalide"));

        // Détection de réutilisation d'un jeton révoqué (vol suspecté de token)
        if (token.isRevoque()) {
            Instant dateRevocation = token.getDateRevocation();
            Duration grace = Duration.ofMinutes(2);
            if (dateRevocation != null && maintenant.isBefore(dateRevocation.plus(grace))) {
                if (token.getRemplaceParHash() != null) {
                    RefreshToken remp = refreshTokenRepository.findByTokenHash(token.getRemplaceParHash()).orElse(null);
                    if (remp != null && !remp.isRevoque() && remp.getDateExpiration().isAfter(maintenant)) {
                        return effectuerRotation(remp, maintenant, deviceId, ip);
                    }
                }
                throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                        "Ce jeton de rafraîchissement vient d'être renouvelé. Veuillez utiliser le nouveau jeton ou vous reconnecter.");
            }
            refreshTokenRepository.revoquerTousPourUtilisateur(token.getUtilisateurId(), maintenant);
            sessionService.invaliderToutes(token.getUtilisateurId());
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Alerte de sécurité : réutilisation de jeton révoqué détectée. Toutes les sessions ont été invalidées.");
        }

        // Expiration
        if (token.getDateExpiration().isBefore(maintenant)) {
            token.revoquer(maintenant);
            refreshTokenRepository.save(token);
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07", "Jeton de rafraîchissement expiré. Veuillez vous reconnecter.");
        }

        return effectuerRotation(token, maintenant, deviceId, ip);
    }

    private TokenPair effectuerRotation(RefreshToken token, Instant maintenant, String deviceId, String ip) {
        Utilisateur u = utilisateurRepository.findById(token.getUtilisateurId())
                .orElseThrow(() -> new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-09", "Utilisateur introuvable"));

        if (!u.getStatutCompte().peutSAuthentifier()) {
            token.revoquer(maintenant);
            refreshTokenRepository.save(token);
            throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-09", "Ce compte est suspendu ou désactivé");
        }

        Long sessionId = token.getSessionId();
        if (sessionId != null) {
            SessionUtilisateur session = sessionRepository.findById(sessionId).orElse(null);
            if (session != null && session.estValide(maintenant)) {
                session.prolonger(maintenant, maintenant.plus(proprietes.session().inactivite()));
                sessionRepository.save(session);
            } else {
                SessionUtilisateur nouvelleSession = sessionRepository.save(
                        new SessionUtilisateur(u.getId(), deviceId != null ? deviceId : token.getDeviceId(),
                                ip != null ? ip : token.getIpCreation(), null, maintenant,
                                maintenant.plus(proprietes.session().inactivite()))
                );
                sessionId = nouvelleSession.getId();
            }
        } else {
            SessionUtilisateur nouvelleSession = sessionRepository.save(
                    new SessionUtilisateur(u.getId(), deviceId != null ? deviceId : token.getDeviceId(),
                            ip != null ? ip : token.getIpCreation(), null, maintenant,
                            maintenant.plus(proprietes.session().inactivite()))
            );
            sessionId = nouvelleSession.getId();
        }

        boolean estAdmin = u instanceof Administrateur;
        Duration accessDuree = estAdmin ? DUREE_ACCESS_ADMIN : DUREE_ACCESS_STANDARD;
        Duration refreshDuree = estAdmin ? DUREE_REFRESH_ADMIN : DUREE_REFRESH_STANDARD;

        // Rotation : ancien révoqué et pointant vers le nouveau
        String nouveauJetonBrut = genererAleatoire();
        String nouveauHash = hacher(nouveauJetonBrut);
        Instant nouvelleExpiration = maintenant.plus(refreshDuree);

        token.revoquer(maintenant, nouveauHash);
        token.enregistrerUtilisation(maintenant);
        refreshTokenRepository.save(token);

        RefreshToken nouveauRefreshToken = new RefreshToken(
                nouveauHash, u.getId(), sessionId,
                deviceId != null ? deviceId : token.getDeviceId(),
                ip != null ? ip : token.getIpCreation(),
                maintenant, nouvelleExpiration
        );
        nouveauRefreshToken.enregistrerUtilisation(maintenant);
        refreshTokenRepository.save(nouveauRefreshToken);

        List<String> permissions = AuthService.codesPermissions(u);
        Instant accessExpiration = maintenant.plus(accessDuree);
        String nouveauAccessToken = jwtService.generer(u.getId(), sessionId, u.typeActeur().name(), permissions, maintenant, accessExpiration);

        AuthService.Profil profil = AuthService.profil(u, permissions);
        return new TokenPair(nouveauAccessToken, nouveauJetonBrut, accessExpiration, nouvelleExpiration, profil);
    }

    @Transactional
    public void revoquerToken(String jetonBrut) {
        if (jetonBrut == null || jetonBrut.isBlank()) {
            return;
        }
        String hash = hacher(jetonBrut.trim());
        refreshTokenRepository.findByTokenHash(hash).ifPresent(t -> {
            t.revoquer(horloge.instant());
            refreshTokenRepository.save(t);
        });
    }

    @Transactional
    public void revoquerPourUtilisateur(long utilisateurId) {
        refreshTokenRepository.revoquerTousPourUtilisateur(utilisateurId, horloge.instant());
    }

    @Transactional
    public void revoquerPourSession(long sessionId) {
        refreshTokenRepository.revoquerPourSession(sessionId, horloge.instant());
    }

    public static String hacher(String raw) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(raw.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 introuvable", e);
        }
    }

    private String genererAleatoire() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return HexFormat.of().formatHex(bytes);
    }
}
