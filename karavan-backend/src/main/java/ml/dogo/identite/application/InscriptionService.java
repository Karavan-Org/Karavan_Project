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
import org.springframework.jdbc.core.JdbcTemplate;
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
    private final JdbcTemplate jdbcTemplate;

    public InscriptionService(UtilisateurRepository utilisateurs, RoleRepository roles, OtpService otp,
                              PasswordEncoder encodeur, AuditApi audit, NotificationApi notifications,
                              DogoProperties proprietes, Clock horloge, JdbcTemplate jdbcTemplate) {
        this.utilisateurs = utilisateurs;
        this.roles = roles;
        this.otp = otp;
        this.encodeur = encodeur;
        this.audit = audit;
        this.notifications = notifications;
        this.proprietes = proprietes;
        this.horloge = horloge;
        this.jdbcTemplate = jdbcTemplate;
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
        utilisateurs.findByTelephone(telephone).ifPresent(this::libererSiInscriptionAbandonnee);
        Role role = roles.findByNom(d.type().name())
                .orElseThrow(() -> new IllegalStateException("Rôle absent de la base : " + d.type()));
        String pinHash = encodeur.encode(d.pin());
        String nom = d.nom().strip();
        var maintenant = horloge.instant();

        String nomBoutique = (d.nomBoutique() != null && !d.nomBoutique().isBlank())
                ? d.nomBoutique().strip()
                : "Boutique " + nom;
        String nomBoutiqueMarche = (d.nomBoutiqueMarche() != null && !d.nomBoutiqueMarche().isBlank())
                ? d.nomBoutiqueMarche().strip()
                : "Boutique " + nom;
        String nomSociete = (d.nomSocieteImport() != null && !d.nomSocieteImport().isBlank())
                ? d.nomSocieteImport().strip()
                : "Société " + nom;

        Utilisateur u = switch (d.type()) {
            case COMMERCANT -> new Commercant(telephone, nom, pinHash, role, maintenant,
                    nomBoutique, d.adresseLivraison(), d.quartierBamako(), d.canalVente());
            case GROSSISTE -> new Grossiste(telephone, nom, pinHash, role, maintenant,
                    nomBoutiqueMarche, d.numeroNif(), d.registreCommerce());
            case COURTIER -> new Courtier(telephone, nom, pinHash, role, maintenant,
                    nomSociete, d.licenceTransit(), d.adresseDepot());
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
        utilisateurs.save(u);
        audit.tracer(u.getId(), "TELEPHONE_VERIFIE", null, "statut=" + u.getStatutCompte());
        notifications.notifier(u.getId(), u.typeActeur().exigeKyc()
                ? "Bienvenue sur Karavan ! Envoyez maintenant votre dossier de vérification (KYC) pour activer votre compte."
                : "Bienvenue sur Karavan ! Votre compte est actif.");
        return new Resultat(u.getId(), u.getStatutCompte().name(), null);
    }

    /**
     * RG-01 : un numéro n'est réservé qu'une fois prouvé par OTP. Une inscription interrompue avant la saisie du
     * code (ou faite avec le numéro de quelqu'un d'autre) ne bloque donc pas le numéro : une nouvelle inscription la
     * remplace aussitôt, sans attendre l'expiration de son code. Un tel compte n'a jamais pu se connecter (connexion refusée sans
     * téléphone vérifié) : il ne possède ni session, ni dossier, ni portefeuille, seulement ses codes, dont
     * l'historique reste compté par numéro (plafond d'envoi de {@link OtpService}).
     */
    private void libererSiInscriptionAbandonnee(Utilisateur existant) {
        if (existant.isTelephoneVerifie()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-01",
                    "Ce numéro de téléphone est déjà enregistré sur un compte "
                            + AuthService.libelleRole(existant.typeActeur()) + ".");
        }
        // Le numéro n'est pas vérifié (inscription non finalisée) : on remplace proprement le brouillon
        long ancienId = existant.getId();
        jdbcTemplate.update("UPDATE code_otp SET utilisateur_id = NULL WHERE utilisateur_id = ?", ancienId);
        jdbcTemplate.update("DELETE FROM notification WHERE utilisateur_id = ?", ancienId);
        jdbcTemplate.update("DELETE FROM session_utilisateur WHERE utilisateur_id = ?", ancienId);
        jdbcTemplate.update("DELETE FROM refresh_token WHERE utilisateur_id = ?", ancienId);
        jdbcTemplate.update("DELETE FROM compte_externe WHERE utilisateur_id = ?", ancienId);
        jdbcTemplate.update("DELETE FROM moyen_paiement_utilisateur WHERE utilisateur_id = ?", ancienId);
        jdbcTemplate.update("DELETE FROM dossier_kyc WHERE utilisateur_id = ?", ancienId);
        utilisateurs.delete(existant);
        utilisateurs.flush();
        audit.tracer(ancienId, "INSCRIPTION_NON_FINALISEE_REMPLACEE", null,
                "type=" + existant.typeActeur() + ", telephone non vérifié");
    }

    private static String exiger(String valeur, String champ) {
        if (valeur == null || valeur.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-01", "Champ obligatoire : " + champ);
        }
        return valeur.strip();
    }
}
