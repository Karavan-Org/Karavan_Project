package ml.dogo.identite.application;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.Telephone;
import ml.dogo.identite.domain.TypeActeur;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.CompteExterne;
import ml.dogo.identite.persistence.CompteExterneRepository;
import ml.dogo.identite.persistence.Commercant;
import ml.dogo.identite.persistence.Courtier;
import ml.dogo.identite.persistence.Grossiste;
import ml.dogo.identite.persistence.Role;
import ml.dogo.identite.persistence.RoleRepository;
import ml.dogo.identite.persistence.SessionUtilisateur;
import ml.dogo.identite.persistence.SessionUtilisateurRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.JwtService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service orchestrant la fédération d'identité OAuth2 Google (RG-07, RG-01, RG-02).
 * Assure la vérification sécurisée, la détection des profils incomplets, la validation OTP,
 * la fusion intelligente par numéro de téléphone vérifié et la création de comptes sans mot de passe.
 */
@Service
public class GoogleAuthService {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleAuthService.class);
    private static final String FOURNISSEUR_GOOGLE = "GOOGLE";

    public record ResultatAuthGoogle(
            String statut, // CONNECTE ou PROFIL_INCOMPLET
            String jetonInscription,
            String sub,
            String email,
            boolean emailVerified,
            String nom,
            String photoUrl,
            String jeton,
            String refreshToken,
            Instant expiration,
            Instant refreshExpiration,
            AuthService.Profil profil
    ) {
        public static ResultatAuthGoogle profilIncomplet(String jetonInscription, GoogleIdTokenInfo info) {
            return new ResultatAuthGoogle(
                    "PROFIL_INCOMPLET",
                    jetonInscription,
                    info.sub(),
                    info.email(),
                    info.emailVerified(),
                    info.nom(),
                    info.photoUrl(),
                    null, null, null, null, null
            );
        }

        public static ResultatAuthGoogle connecte(String jeton, String refreshToken, Instant expiration,
                                                  Instant refreshExpiration, AuthService.Profil profil) {
            return new ResultatAuthGoogle(
                    "CONNECTE",
                    null, null, null, false, null, null,
                    jeton, refreshToken, expiration, refreshExpiration, profil
            );
        }
    }

    public record DemandeCompleterGoogle(
            String jetonInscription,
            String telephone,
            String codeOtp,
            TypeActeur typeActeur,
            String nomBoutique,
            String quartierBamako,
            String deviceId
    ) {
    }

    public record ReponseOtpGoogle(
            String statut,
            String telephone,
            String message,
            String codeOtp
    ) {
    }

    private final GoogleTokenVerifier googleTokenVerifier;
    private final CompteExterneRepository comptesExternes;
    private final UtilisateurRepository utilisateurs;
    private final RoleRepository roles;
    private final SessionUtilisateurRepository sessions;
    private final RefreshTokenService refreshTokenService;
    private final OtpService otpService;
    private final JetonInscriptionTemporaireService jetonInscriptionService;
    private final LimiteurDebitIp limiteurDebitIp;
    private final JwtService jwt;
    private final DogoProperties proprietes;
    private final Clock horloge;
    private final AuditApi audit;
    private final NotificationApi notifications;

    @org.springframework.beans.factory.annotation.Autowired
    public GoogleAuthService(GoogleTokenVerifier googleTokenVerifier,
                             CompteExterneRepository comptesExternes,
                             UtilisateurRepository utilisateurs,
                             RoleRepository roles,
                             SessionUtilisateurRepository sessions,
                             RefreshTokenService refreshTokenService,
                             OtpService otpService,
                             JetonInscriptionTemporaireService jetonInscriptionService,
                             LimiteurDebitIp limiteurDebitIp,
                             JwtService jwt,
                             DogoProperties proprietes,
                             Clock horloge,
                             AuditApi audit,
                             NotificationApi notifications) {
        this.googleTokenVerifier = googleTokenVerifier;
        this.comptesExternes = comptesExternes;
        this.utilisateurs = utilisateurs;
        this.roles = roles;
        this.sessions = sessions;
        this.refreshTokenService = refreshTokenService;
        this.otpService = otpService;
        this.jetonInscriptionService = jetonInscriptionService;
        this.limiteurDebitIp = limiteurDebitIp;
        this.jwt = jwt;
        this.proprietes = proprietes;
        this.horloge = horloge;
        this.audit = audit;
        this.notifications = notifications;
    }

    GoogleAuthService(GoogleTokenVerifier googleTokenVerifier,
                      CompteExterneRepository comptesExternes,
                      UtilisateurRepository utilisateurs,
                      RoleRepository roles,
                      SessionUtilisateurRepository sessions,
                      RefreshTokenService refreshTokenService,
                      OtpService otpService,
                      JetonInscriptionTemporaireService jetonInscriptionService,
                      LimiteurDebitIp limiteurDebitIp,
                      JwtService jwt,
                      DogoProperties proprietes,
                      Clock horloge,
                      AuditApi audit) {
        this(googleTokenVerifier, comptesExternes, utilisateurs, roles, sessions,
                refreshTokenService, otpService, jetonInscriptionService, limiteurDebitIp,
                jwt, proprietes, horloge, audit, null);
    }

    public enum ModeAuthGoogle {
        CONNEXION,
        INSCRIPTION
    }

    /**
     * Traite un ID Token Google :
     * 1. Si le sub Google est déjà associé à un compte :
     *    - En mode CONNEXION (ou neutre) → connexion directe et émission des tokens.
     *    - En mode INSCRIPTION → erreur CONFLIT invitant à passer par l'écran de connexion.
     * 2. Si le sub est inconnu :
     *    - En mode CONNEXION → erreur COMPTE_INEXISTANT invitant à passer par l'écran d'inscription.
     *    - En mode INSCRIPTION (ou neutre) → réponse « PROFIL_INCOMPLET » avec jeton temporaire d'inscription.
     */
    @Transactional
    public ResultatAuthGoogle authentifier(String idToken, String deviceId, String ip) {
        return authentifier(idToken, deviceId, ip, null, null);
    }

    @Transactional
    public ResultatAuthGoogle authentifier(String idToken, String deviceId, String ip, TypeActeur typeActeurAttendu) {
        return authentifier(idToken, deviceId, ip, typeActeurAttendu, null);
    }

    @Transactional
    public ResultatAuthGoogle authentifier(String idToken, String deviceId, String ip,
                                           TypeActeur typeActeurAttendu, ModeAuthGoogle mode) {
        limiteurDebitIp.verifierLimite(ip);

        // 1. Vérification cryptographique des claims Google
        GoogleIdTokenInfo info = googleTokenVerifier.verifier(idToken);
        Instant maintenant = horloge.instant();

        // 2. Recherche du compte lié au sub Google
        var compteOpt = comptesExternes.findByFournisseurAndSubAvecUtilisateur(FOURNISSEUR_GOOGLE, info.sub());
        if (compteOpt.isPresent()) {
            Utilisateur u = compteOpt.get().getUtilisateur();
            // Aucun mélange entre les espaces Commerçant, Grossiste et Courtier après le choix initial
            if (typeActeurAttendu != null && u.typeActeur() != typeActeurAttendu) {
                throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-01",
                        "Ce compte Google est déjà rattaché à un compte " + AuthService.libelleRole(u.typeActeur())
                                + " et ne peut pas être utilisé dans l'espace " + AuthService.libelleRole(typeActeurAttendu) + ".");
            }
            if (mode == ModeAuthGoogle.INSCRIPTION) {
                throw new ErreurMetier(CodeErreur.CONFLIT, "RG-01",
                        "Un compte " + AuthService.libelleRole(u.typeActeur())
                                + " existe déjà avec cette adresse Google. Veuillez utiliser l'écran Se connecter.");
            }
            u.verifierNonVerrouille(maintenant);

            if (!u.getStatutCompte().peutSAuthentifier()) {
                throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-09", "Ce compte est suspendu ou désactivé");
            }
            if (!u.isTelephoneVerifie()) {
                throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-02",
                        "Téléphone non vérifié : veuillez confirmer le code reçu par SMS");
            }
            // RG-03 : le commerçant n'est soumis à aucune validation KYC, il est actif dès que son téléphone est vérifié
            if (!u.typeActeur().exigeKyc() && u.getStatutCompte() == StatutCompte.EN_ATTENTE) {
                u.changerStatut(StatutCompte.ACTIF);
            }

            // Mise à jour de l'email ou photo si manquant
            if ((u.getEmail() == null || u.getEmail().isBlank()) && info.email() != null && info.emailVerified()) {
                u.modifierEmail(info.email());
            }
            if (u.getPhotoUrl() == null && info.photoUrl() != null && !info.photoUrl().isBlank()) {
                u.modifierPhoto(info.photoUrl());
            }
            u.reinitialiserEchecs();
            utilisateurs.save(u);

            audit.tracer(u.getId(), "CONNEXION_GOOGLE", null, "fournisseur=GOOGLE");

            AuthService.Connexion c = creerSession(u, deviceId, ip, maintenant);
            return ResultatAuthGoogle.connecte(c.jeton(), c.refreshToken(), c.expiration(), c.refreshExpiration(), c.profil());
        }

        // 3. Sub inconnu : en mode CONNEXION, refuser et inviter l'utilisateur à s'inscrire
        if (mode == ModeAuthGoogle.CONNEXION) {
            audit.tracer(null, "CONNEXION_GOOGLE_REFUSEE_INEXISTANT", null,
                    "email=" + (info.emailVerified() ? info.email() : "non-verifie"));
            String libelleRole = typeActeurAttendu != null ? " " + AuthService.libelleRole(typeActeurAttendu) : "";
            throw new ErreurMetier(CodeErreur.COMPTE_INEXISTANT, "RG-07",
                    "Aucun compte" + libelleRole + " n'est associé à cette adresse Google. Veuillez d'abord créer un compte via l'inscription.");
        }

        // En mode INSCRIPTION (ou non précisé) : émission du jeton temporaire d'inscription, sans créer de compte en base
        String jetonInscription = jetonInscriptionService.emettre(info);
        audit.tracer(null, "GOOGLE_PROFIL_INCOMPLET", null,
                "email=" + (info.emailVerified() ? info.email() : "non-verifie"));

        return ResultatAuthGoogle.profilIncomplet(jetonInscription, info);
    }

    /**
     * Étape 1 de complétion : validation du jeton temporaire et émission de l'OTP SMS sur le téléphone malien (+223).
     */
    @Transactional
    public ReponseOtpGoogle declencherOtpCompleter(String jetonInscription, String telephoneBrut, String ip) {
        return declencherOtpCompleter(jetonInscription, telephoneBrut, null, ip);
    }

    @Transactional
    public ReponseOtpGoogle declencherOtpCompleter(String jetonInscription, String telephoneBrut,
                                                   TypeActeur typeActeurAttendu, String ip) {
        limiteurDebitIp.verifierLimite(ip);

        // Vérification de validité du jeton temporaire
        jetonInscriptionService.valider(jetonInscription);

        String telephone = Telephone.normaliser(telephoneBrut);

        // Empêcher tout mélange entre espaces : si ce numéro appartient déjà à un autre type d'acteur, refuser avant l'OTP
        if (typeActeurAttendu != null) {
            utilisateurs.findByTelephone(telephone).ifPresent(existant -> {
                if (existant.typeActeur() != typeActeurAttendu) {
                    throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-01",
                            "Ce numéro de téléphone est déjà rattaché à un compte "
                                    + AuthService.libelleRole(existant.typeActeur())
                                    + " et ne peut pas être utilisé dans l'espace "
                                    + AuthService.libelleRole(typeActeurAttendu) + ".");
                }
            });
        }

        String codeOtp = otpService.emettrePourTelephone(telephone, null);

        return new ReponseOtpGoogle(
                "OTP_ENVOYE",
                telephone,
                "Un code de vérification SMS a été envoyé au numéro " + telephone,
                proprietes.otp().afficherDansReponse() ? codeOtp : null
        );
    }

    /**
     * Étape 2 de complétion : vérification de l'OTP SMS, création ou fusion du compte, et ouverture de session.
     */
    @Transactional
    public AuthService.Connexion completerEtConnecter(DemandeCompleterGoogle d, String ip) {
        limiteurDebitIp.verifierLimite(ip);

        GoogleIdTokenInfo info = jetonInscriptionService.valider(d.jetonInscription());
        String telephone = Telephone.normaliser(d.telephone());

        // Vérification stricte de non-mélange des rôles AVANT de consommer le jeton d'inscription
        var existantOpt = utilisateurs.findByTelephone(telephone);
        if (existantOpt.isPresent() && d.typeActeur() != null && existantOpt.get().typeActeur() != d.typeActeur()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-01",
                    "Ce numéro de téléphone est déjà rattaché à un compte "
                            + AuthService.libelleRole(existantOpt.get().typeActeur())
                            + " et ne peut pas être utilisé dans l'espace "
                            + AuthService.libelleRole(d.typeActeur()) + ".");
        }

        // Vérification stricte du code OTP
        if (d.codeOtp() == null || d.codeOtp().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-02", "Le code de vérification SMS est obligatoire");
        }
        otpService.verifierPourTelephone(telephone, d.codeOtp().strip());

        // Consommation à usage unique du jeton temporaire
        jetonInscriptionService.consommer(d.jetonInscription());

        Instant maintenant = horloge.instant();
        Utilisateur u;

        // Vérification d'un compte existant du MÊME rôle avec ce numéro (Fusion de compte au sein du même espace uniquement)
        if (existantOpt.isPresent()) {
            u = existantOpt.get();

            // Vérifier que ce sub n'est pas déjà rattaché
            if (comptesExternes.existsByFournisseurAndSub(FOURNISSEUR_GOOGLE, info.sub())) {
                throw new ErreurMetier(CodeErreur.CONFLIT, "RG-01", "Ce compte Google est déjà associé à un autre profil");
            }

            // Rattachement du compte externe Google au compte existant
            comptesExternes.save(new CompteExterne(FOURNISSEUR_GOOGLE, info.sub(), u, info.email(), maintenant));

            if (!u.isTelephoneVerifie()) {
                u.marquerTelephoneVerifie();
            }
            if (!u.typeActeur().exigeKyc() && u.getStatutCompte() == StatutCompte.EN_ATTENTE) {
                u.changerStatut(StatutCompte.ACTIF);
            }
            if ((u.getEmail() == null || u.getEmail().isBlank()) && info.email() != null && info.emailVerified()) {
                u.modifierEmail(info.email());
            }
            if (u.getPhotoUrl() == null && info.photoUrl() != null && !info.photoUrl().isBlank()) {
                u.modifierPhoto(info.photoUrl());
            }
            utilisateurs.save(u);

            audit.tracer(u.getId(), "FUSION_COMPTE_GOOGLE", null, "telephone=" + telephone + ", sub=" + info.sub());
        } else {
            // Création d'un nouveau compte sans mot de passe initial
            TypeActeur type = d.typeActeur() != null ? d.typeActeur() : TypeActeur.COMMERCANT;
            if (type == TypeActeur.ADMINISTRATEUR) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-01", "Inscription administrateur interdite");
            }

            Role role = roles.findByNom(type.name())
                    .orElseThrow(() -> new IllegalStateException("Rôle absent de la base : " + type));

            String nomDefaut = switch (type) {
                case GROSSISTE -> "Grossiste Karavan";
                case COURTIER -> "Courtier Karavan";
                default -> "Commerçant Karavan";
            };
            String nom = (info.nom() != null && !info.nom().isBlank()) ? info.nom().strip() : nomDefaut;
            String boutique = (d.nomBoutique() != null && !d.nomBoutique().isBlank())
                    ? d.nomBoutique().strip()
                    : "Boutique " + nom;
            String entreprise = (d.nomBoutique() != null && !d.nomBoutique().isBlank())
                    ? d.nomBoutique().strip()
                    : "Entreprise " + nom;
            String societe = (d.nomBoutique() != null && !d.nomBoutique().isBlank())
                    ? d.nomBoutique().strip()
                    : "Société " + nom;
            String quartier = (d.quartierBamako() != null && !d.quartierBamako().isBlank())
                    ? d.quartierBamako().strip()
                    : null;

            u = switch (type) {
                case COMMERCANT -> new Commercant(telephone, nom, null, role, maintenant,
                        boutique, null, quartier, null);
                case GROSSISTE -> new Grossiste(telephone, nom, null, role, maintenant,
                        entreprise, null, null);
                case COURTIER -> new Courtier(telephone, nom, null, role, maintenant,
                        societe, null, null);
                default -> throw new IllegalStateException();
            };

            u.marquerTelephoneVerifie();
            if (info.email() != null && !info.email().isBlank()) {
                u.modifierEmail(info.email().strip().toLowerCase());
            }
            if (info.photoUrl() != null && !info.photoUrl().isBlank()) {
                u.modifierPhoto(info.photoUrl().strip());
            }
            // RG-03 : le commerçant est actif immédiatement sans validation ; seuls Grossiste et Courtier attendent le KYC
            if (!type.exigeKyc()) {
                u.changerStatut(StatutCompte.ACTIF);
            }

            u = utilisateurs.save(u);

            // Création de la ligne compte_externe
            comptesExternes.save(new CompteExterne(FOURNISSEUR_GOOGLE, info.sub(), u, info.email(), maintenant));

            audit.tracer(u.getId(), "CREATION_COMPTE_GOOGLE", null,
                    "type=" + type + ", statut=" + u.getStatutCompte() + ", telephone=" + telephone);

            if (notifications != null) {
                notifications.notifier(u.getId(), type.exigeKyc()
                        ? "Bienvenue sur Karavan ! Envoyez maintenant votre dossier de vérification (KYC) pour activer votre compte."
                        : "Bienvenue sur Karavan ! Votre compte est actif.");
            }
        }

        return creerSession(u, d.deviceId(), ip, maintenant);
    }

    private AuthService.Connexion creerSession(Utilisateur u, String deviceId, String ip, Instant maintenant) {
        SessionUtilisateur session = sessions.save(new SessionUtilisateur(u.getId(), deviceId, ip, null, maintenant,
                maintenant.plus(proprietes.session().inactivite())));

        List<String> permissions = AuthService.codesPermissions(u);
        boolean estAdmin = u instanceof Administrateur;
        Duration accessDuration = estAdmin ? RefreshTokenService.DUREE_ACCESS_ADMIN : RefreshTokenService.DUREE_ACCESS_STANDARD;
        Instant expiration = maintenant.plus(accessDuration);

        String jeton = jwt.generer(u.getId(), session.getId(), u.typeActeur().name(), permissions, maintenant, expiration);
        var nouveauRt = refreshTokenService.creerToken(u.getId(), session.getId(), deviceId, ip, estAdmin);

        return new AuthService.Connexion(jeton, nouveauRt.jetonBrut(), expiration, nouveauRt.expiration(),
                AuthService.profil(u, permissions));
    }
}

