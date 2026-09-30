package ml.dogo.identite.application;

import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.domain.RegleAcces;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.Telephone;
import ml.dogo.identite.domain.TypeActeur;
import ml.dogo.identite.persistence.Commercant;
import ml.dogo.identite.persistence.Courtier;
import ml.dogo.identite.persistence.Grossiste;
import ml.dogo.identite.persistence.Role;
import ml.dogo.identite.persistence.RoleRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import java.time.Clock;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Création de compte et activation par OTP (RG-01, RG-02, RG-03). */
@Service
public class InscriptionService {

    public record Demande(TypeActeur type, String telephone, String nom, String pin,
                          String nomBoutique, String adresseLivraison, String quartierBamako, String canalVente,
                          String nomBoutiqueMarche, String numeroNif, String registreCommerce,
                          String nomSocieteImport, String licenceTransit, String adresseDepot) {
    }

    /** {@code codeOtp} n'est renseigné qu'en mode démonstration (dogo.otp.afficher-dans-reponse). */
    public record Resultat(long utilisateurId, String statut, String codeOtp) {
    }

    private final UtilisateurRepository utilisateurs;
    private final RoleRepository roles;
    private final OtpService otp;
    private final PasswordEncoder encodeur;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final DogoProperties proprietes;
    private final Clock horloge;

    public InscriptionService(UtilisateurRepository utilisateurs, RoleRepository roles, OtpService otp,
                              PasswordEncoder encodeur, AuditApi audit, NotificationApi notifications,
                              DogoProperties proprietes, Clock horloge) {
        this.utilisateurs = utilisateurs;
        this.roles = roles;
        this.otp = otp;
        this.encodeur = encodeur;
        this.audit = audit;
        this.notifications = notifications;
        this.proprietes = proprietes;
        this.horloge = horloge;
    }

    @Transactional
    public Resultat inscrire(Demande d) {
        if (d.type() == null || d.type() == TypeActeur.ADMINISTRATEUR) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-01",
                    "Type de compte invalide : COMMERCANT, GROSSISTE ou COURTIER");
        }
        String telephone = Telephone.normaliser(d.telephone());
        RegleAcces.verifierFormatPin(d.pin());
        if (d.nom() == null || d.nom().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-01", "Le nom est obligatoire");
        }
        if (utilisateurs.existsByTelephone(telephone)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-01", "Ce numéro de téléphone est déjà utilisé");
        }
        Role role = roles.findByNom(d.type().name())
                .orElseThrow(() -> new IllegalStateException("Rôle absent de la base : " + d.type()));
        String pinHash = encodeur.encode(d.pin());
        String nom = d.nom().strip();
        var maintenant = horloge.instant();

        Utilisateur u = switch (d.type()) {
            case COMMERCANT -> new Commercant(telephone, nom, pinHash, role, maintenant,
                    exiger(d.nomBoutique(), "nomBoutique"), d.adresseLivraison(), d.quartierBamako(), d.canalVente());
            case GROSSISTE -> new Grossiste(telephone, nom, pinHash, role, maintenant,
                    exiger(d.nomBoutiqueMarche(), "nomBoutiqueMarche"), d.numeroNif(), d.registreCommerce());
            case COURTIER -> new Courtier(telephone, nom, pinHash, role, maintenant,
                    exiger(d.nomSocieteImport(), "nomSocieteImport"), d.licenceTransit(), d.adresseDepot());
            default -> throw new IllegalStateException();
        };
        u = utilisateurs.save(u);
        audit.tracer(u.getId(), "COMPTE_CREE", null, "type=" + d.type() + ", statut=" + u.getStatutCompte());
        String code = otp.emettre(u);
        return new Resultat(u.getId(), u.getStatutCompte().name(),
                proprietes.otp().afficherDansReponse() ? code : null);
    }

    /** Renvoie un code à un compte dont le téléphone n'est pas encore vérifié. */
    @Transactional
    public Resultat renvoyerOtp(String telephoneBrut) {
        String telephone = Telephone.normaliser(telephoneBrut);
        Utilisateur u = utilisateurs.findByTelephone(telephone)
                .filter(x -> !x.isTelephoneVerifie())
                .orElseThrow(() -> new ErreurMetier(CodeErreur.NON_TROUVE, "RG-02",
                        "Aucune vérification en attente pour ce numéro"));
        String code = otp.emettre(u);
        return new Resultat(u.getId(), u.getStatutCompte().name(),
                proprietes.otp().afficherDansReponse() ? code : null);
    }

    /** RG-02 + RG-03 : le bon code vérifie le téléphone ; un Commerçant devient actif, les autres attendent le KYC. */
    @Transactional
    public Resultat verifierOtp(String telephoneBrut, String code) {
        String telephone = Telephone.normaliser(telephoneBrut);
        Utilisateur u = utilisateurs.findByTelephone(telephone)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.OTP_INVALIDE, "RG-02", "Code invalide ou expiré"));
        if (u.isTelephoneVerifie()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-02", "Ce numéro est déjà vérifié");
        }
        otp.verifier(u.getId(), code);
        u.marquerTelephoneVerifie();
        if (!u.typeActeur().exigeKyc() && u.getStatutCompte() == StatutCompte.EN_ATTENTE) {
            u.changerStatut(StatutCompte.ACTIF);
        }
        audit.tracer(u.getId(), "TELEPHONE_VERIFIE", null, "statut=" + u.getStatutCompte());
        notifications.notifier(u.getId(), u.typeActeur().exigeKyc()
                ? "Bienvenue sur DoGo ! Envoyez maintenant votre dossier de vérification (KYC) pour activer votre compte."
                : "Bienvenue sur DoGo ! Votre compte est actif.");
        return new Resultat(u.getId(), u.getStatutCompte().name(), null);
    }

    private static String exiger(String valeur, String champ) {
        if (valeur == null || valeur.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-01", "Champ obligatoire : " + champ);
        }
        return valeur.strip();
    }
}
