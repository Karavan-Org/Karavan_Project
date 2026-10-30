package ml.dogo.identite.application;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import ml.dogo.identite.persistence.CodeOtp;
import ml.dogo.identite.persistence.CodeOtpRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Émission et vérification des codes à usage unique (RG-02). Les codes sont stockés hachés (RG-71). */
@Service
public class OtpService {

    /** Délai minimal entre deux envois pour un même compte. */
    static final Duration DELAI_RENVOI = Duration.ofSeconds(30);

    /**
     * Plafond d'envois par numéro sur 24 h glissantes : avec 3 essais par code, deviner un code à 4 chiffres
     * devient impraticable (15 essais par jour sur 10 000), et un numéro ne peut pas être inondé de SMS.
     */
    static final int MAX_ENVOIS_PAR_JOUR = 5;

    private final CodeOtpRepository otps;
    private final CompteursAuthentification compteurs;
    private final PasswordEncoder encodeur;
    private final NotificationApi notifications;
    private final DogoProperties proprietes;
    private final Clock horloge;
    private final SecureRandom alea = new SecureRandom();

    public OtpService(CodeOtpRepository otps, CompteursAuthentification compteurs, PasswordEncoder encodeur,
                      NotificationApi notifications, DogoProperties proprietes, Clock horloge) {
        this.otps = otps;
        this.compteurs = compteurs;
        this.encodeur = encodeur;
        this.notifications = notifications;
        this.proprietes = proprietes;
        this.horloge = horloge;
    }

    /** Génère un nouveau code (les précédents sont annulés), l'envoie par SMS et le renvoie en clair à l'appelant. */
    @Transactional
    public String emettre(Utilisateur utilisateur) {
        return emettrePourTelephone(utilisateur.getTelephone(), utilisateur.getId());
    }

    @Transactional
    public String emettrePourTelephone(String telephoneBrut, Long utilisateurIdOptionnel) {
        Instant maintenant = horloge.instant();
        String telephone = ml.dogo.identite.domain.Telephone.normaliser(telephoneBrut);
        // Comptés par numéro et non par compte : remplacer une inscription abandonnée ne remet rien à zéro
        otps.findFirstByTelephoneOrderByDateCreationDesc(telephone).ifPresent(dernier -> {
            Duration delai = proprietes.otp().afficherDansReponse() ? Duration.ofSeconds(2) : DELAI_RENVOI;
            if (maintenant.isBefore(dernier.getDateCreation().plus(delai))) {
                throw new ErreurMetier(CodeErreur.CONFLIT, "RG-02",
                        "Un code vient d'être envoyé, patientez quelques secondes avant d'en redemander un");
            }
        });
        if (otps.countByTelephoneAndDateCreationAfter(telephone, maintenant.minus(Duration.ofHours(24)))
                >= MAX_ENVOIS_PAR_JOUR) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-02",
                    "Trop de codes demandés pour ce numéro : réessayez dans 24 heures ou contactez le support");
        }
        if (utilisateurIdOptionnel != null) {
            otps.invaliderAnciens(utilisateurIdOptionnel);
        }
        String code = String.format("%04d", alea.nextInt(10_000));
        otps.save(new CodeOtp(utilisateurIdOptionnel, telephone, encodeur.encode(code),
                maintenant.plus(proprietes.otp().validite()), maintenant));
        long minutes = Math.max(1, proprietes.otp().validite().toMinutes());
        notifications.envoyerSms(telephone,
                "Karavan : votre code de vérification est " + code + ". Il est valable " + minutes + " min.");
        return code;
    }

    @Transactional
    public void verifierPourTelephone(String telephoneBrut, String saisi) {
        Instant maintenant = horloge.instant();
        String telephone = ml.dogo.identite.domain.Telephone.normaliser(telephoneBrut);
        CodeOtp otp = otps.findFirstByTelephoneOrderByDateCreationDesc(telephone)
                .filter(o -> !o.isUtilise())
                .orElseThrow(() -> new ErreurMetier(CodeErreur.OTP_INVALIDE, "RG-02", "Code invalide ou expiré"));
        verifierCodeOtp(otp, saisi, maintenant);
    }

    /**
     * Vérifie un code saisi : une tentative est réservée d'abord (atomique), puis le code est comparé, puis consommé.
     * À appeler depuis une transaction ; les échecs restent comptés même si elle est annulée.
     */
    @Transactional
    public void verifier(long utilisateurId, String saisi) {
        Instant maintenant = horloge.instant();
        CodeOtp otp = otps.findFirstByUtilisateurIdAndUtiliseFalseOrderByDateCreationDesc(utilisateurId)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.OTP_INVALIDE, "RG-02", "Code invalide ou expiré"));
        verifierCodeOtp(otp, saisi, maintenant);
    }

    private void verifierCodeOtp(CodeOtp otp, String saisi, Instant maintenant) {
        otp.verifierUtilisable(proprietes.otp().maxTentatives(), maintenant);
        if (!compteurs.reserverTentativeOtp(otp.getId(), proprietes.otp().maxTentatives(), maintenant)) {
            throw new ErreurMetier(CodeErreur.OTP_INVALIDE, "RG-02", "Code invalide ou expiré");
        }
        boolean valide = saisi != null && encodeur.matches(saisi, otp.getCodeHash());
        if (!valide) {
            throw new ErreurMetier(CodeErreur.OTP_INVALIDE, "RG-02", "Code invalide ou expiré");
        }
        if (otps.consommer(otp.getId()) != 1) {
            throw new ErreurMetier(CodeErreur.OTP_INVALIDE, "RG-02", "Code invalide ou expiré");
        }
    }
}
