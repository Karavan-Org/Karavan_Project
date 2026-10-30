package ml.dogo.identite.application;

import java.time.Clock;
import java.time.Instant;
import java.util.regex.Pattern;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service de gestion du Code de Sécurité à 4 chiffres (PIN Administrateur) pour la validation
 * de toutes les actions sensibles (KYC, suspension, suppressions, notifications, déblocages de fonds).
 */
@Service
public class AdminSecuriteService {

    private static final Pattern PATTERN_4_CHIFFRES = Pattern.compile("^\\d{4}$");

    /**
     * Code remis à tout nouvel administrateur. Il ne valide aucune action : il sert uniquement à prouver, au premier
     * paramétrage, que l'on détient le compte, et doit aussitôt être remplacé par un code personnel (RG-SEC-03).
     */
    static final String CODE_PROVISOIRE = "1234";

    public record StatutSecuriteVue(boolean configure, Instant dateConfiguration, String matricule) {
    }

    private final UtilisateurRepository utilisateurs;
    private final PasswordEncoder encodeur;
    private final AuditApi audit;
    private final Clock horloge;

    public AdminSecuriteService(UtilisateurRepository utilisateurs, PasswordEncoder encodeur,
                                AuditApi audit, Clock horloge) {
        this.utilisateurs = utilisateurs;
        this.encodeur = encodeur;
        this.audit = audit;
        this.horloge = horloge;
    }

    @Transactional(readOnly = true)
    public StatutSecuriteVue obtenirStatut(long adminId) {
        Administrateur admin = trouverAdmin(adminId);
        return new StatutSecuriteVue(admin.hasCodeSecurite(), admin.getCodeSecuriteDate(), admin.getMatriculeAgent());
    }

    @Transactional
    public void configurerCode(long adminId, String nouveauCode, String ancienCode) {
        configurerCode(adminId, nouveauCode, ancienCode, null);
    }

    /**
     * Code oublié : l'administrateur peut redéfinir son code en se ré-authentifiant avec son mot de
     * passe de connexion à la place de l'ancien code.
     */
    @Transactional
    public void configurerCode(long adminId, String nouveauCode, String ancienCode, String motDePasse) {
        validerFormatCode(nouveauCode);

        if (CODE_PROVISOIRE.equals(nouveauCode)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-SEC-03",
                    "Le code provisoire ne peut pas devenir votre code personnel : choisissez-en un autre.");
        }

        Administrateur admin = trouverAdmin(adminId);

        if (!admin.hasCodeSecurite()) {
            // Premier paramétrage : l'administrateur prouve qu'il a reçu le code provisoire, puis le remplace
            if (!CODE_PROVISOIRE.equals(ancienCode)) {
                audit.tracer(adminId, "ECHEC_MODIFICATION_CODE_SECURITE", null,
                        "Premier paramétrage avec un code provisoire erroné");
                throw new ErreurMetier(CodeErreur.CODE_SECURITE_INVALIDE, "RG-SEC-02",
                        "Le code provisoire est incorrect.");
            }
        } else {
            // Code déjà personnalisé : l'ancien code choisi (ou le mot de passe de connexion) est obligatoire
            if (motDePasse != null && !motDePasse.isBlank()) {
                if (!admin.hasMotDePasse() || !encodeur.matches(motDePasse, admin.getMotDePasseHash())) {
                    audit.tracer(adminId, "ECHEC_MODIFICATION_CODE_SECURITE", null,
                            "Tentative de réinitialisation avec un mot de passe erroné");
                    throw new ErreurMetier(CodeErreur.CODE_SECURITE_INVALIDE, "RG-SEC-02",
                            "Mot de passe de connexion incorrect.");
                }
            } else if (ancienCode == null || ancienCode.isBlank()) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-SEC-01",
                        "L'ancien code de sécurité à 4 chiffres (ou votre mot de passe) est obligatoire pour le modifier.");
            } else if (!encodeur.matches(ancienCode, admin.getCodeSecuriteHash())) {
                audit.tracer(adminId, "ECHEC_MODIFICATION_CODE_SECURITE", null,
                        "Tentative de modification avec un ancien code erroné");
                throw new ErreurMetier(CodeErreur.CODE_SECURITE_INVALIDE, "RG-SEC-02",
                        "L'ancien code de sécurité à 4 chiffres est incorrect.");
            }
            if (encodeur.matches(nouveauCode, admin.getCodeSecuriteHash())) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-SEC-03",
                        "Le nouveau code doit être différent du code actuel.");
            }
        }

        Instant maintenant = horloge.instant();
        admin.definirCodeSecurite(encodeur.encode(nouveauCode), maintenant);
        utilisateurs.save(admin);

        audit.tracer(adminId, "CODE_SECURITE_ADMIN_CONFIGURE", null,
                "Code de sécurité à 4 chiffres configuré avec succès");
    }

    @Transactional
    public void verifierCode(long adminId, String code) {
        validerFormatCode(code);

        Administrateur admin = trouverAdmin(adminId);

        if (!admin.hasCodeSecurite()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-SEC-01",
                    "Vous devez obligatoirement configurer votre code de sécurité à 4 chiffres avant de valider cette action.");
        }

        if (!encodeur.matches(code, admin.getCodeSecuriteHash())) {
            audit.tracer(adminId, "ECHEC_VALIDATION_CODE_SECURITE", null,
                    "Saisie d'un code de sécurité à 4 chiffres erroné");
            throw new ErreurMetier(CodeErreur.CODE_SECURITE_INVALIDE, "RG-SEC-02",
                    "Code de sécurité à 4 chiffres incorrect.");
        }

        audit.tracer(adminId, "CODE_SECURITE_VALIDE", null, "Validation sécurisée par code à 4 chiffres");
    }

    private void validerFormatCode(String code) {
        if (code == null || !PATTERN_4_CHIFFRES.matcher(code).matches()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-SEC-01",
                    "Le code de sécurité doit être composé d'exactement 4 chiffres (0-9).");
        }
    }

    private Administrateur trouverAdmin(long adminId) {
        return utilisateurs.findById(adminId)
                .filter(u -> u instanceof Administrateur)
                .map(u -> (Administrateur) u)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-SEC-00",
                        "Compte administrateur introuvable ou non autorisé."));
    }
}
