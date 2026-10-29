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
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.JwtService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service orchestrant la fédération d'identité OAuth2 / OIDC Auth0 (RG-07, RG-01, RG-02).
 * Assure la vérification sécurisée, la détection des profils incomplets, la validation OTP,
 * la fusion intelligente par numéro de téléphone vérifié et la création de comptes Karavan.
 */
@Service
public class Auth0AuthService {

    private static final Logger LOG = LoggerFactory.getLogger(Auth0AuthService.class);
    public static final String FOURNISSEUR_AUTH0 = "AUTH0";

    public record ResultatAuth0(
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
        public static ResultatAuth0 profilIncomplet(String jetonInscription, Auth0UserInfo info) {
            return new ResultatAuth0(
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

        public static ResultatAuth0 connecte(String jeton, String refreshToken, Instant expiration,
                                             Instant refreshExpiration, AuthService.Profil profil) {
            return new ResultatAuth0(
                    "CONNECTE",
                    null, null, null, false, null, null,
                    jeton, refreshToken, expiration, refreshExpiration, profil
            );
        }
    }

    public record DemandeCompleterAuth0(
            String jetonInscription,
            String telephone,
            String codeOtp,
            TypeActeur typeActeur,
            String nomBoutique,
            String quartierBamako,
            String deviceId
    ) {
    }

    public record ReponseOtpAuth0(
            String statut,
            String telephone,
            String message,
            String codeOtp
    ) {
    }

    private final Auth0TokenVerifier auth0TokenVerifier;
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

    public Auth0AuthService(Auth0TokenVerifier auth0TokenVerifier,
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
        this.auth0TokenVerifier = auth0TokenVerifier;
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
    }

    /**
     * Traite un jeton Auth0 :
     * 1. Si le sub Auth0 est déjà associé à un compte → connexion directe et émission des tokens Karavan.
     * 2. Si le sub est inconnu → réponse « PROFIL_INCOMPLET » avec jeton temporaire d'inscription.
     */
    @Transactional
    public ResultatAuth0 authentifier(String token, String deviceId, String ip) {
        limiteurDebitIp.verifierLimite(ip);

        // 1. Vérification cryptographique des claims Auth0
        Auth0UserInfo info = auth0TokenVerifier.verifier(token);
        Instant maintenant = horloge.instant();

        // 2. Recherche du compte lié au sub Auth0
        var compteOpt = comptesExternes.findByFournisseurAndSubAvecUtilisateur(FOURNISSEUR_AUTH0, info.sub());
        if (compteOpt.isPresent()) {
            Utilisateur u = compteOpt.get().getUtilisateur();
            u.verifierNonVerrouille(maintenant);

            if (!u.getStatutCompte().peutSAuthentifier()) {
                throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-09", "Ce compte est suspendu ou désactivé");
            }
            if (!u.isTelephoneVerifie()) {
                throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-02",
                        "Téléphone non vérifié : veuillez confirmer le code reçu par SMS");
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

            audit.tracer(u.getId(), "CONNEXION_AUTH0", null, "fournisseur=AUTH0");

            AuthService.Connexion c = creerSession(u, deviceId, ip, maintenant);
            return ResultatAuth0.connecte(c.jeton(), c.refreshToken(), c.expiration(), c.refreshExpiration(), c.profil());
        }

        // 3. Sub inconnu : émission du jeton temporaire d'inscription, sans créer de compte en base
        String jetonInscription = jetonInscriptionService.emettreAuth0(info);
        audit.tracer(null, "AUTH0_PROFIL_INCOMPLET", null,
                "email=" + (info.emailVerified() ? info.email() : "non-verifie"));

        return ResultatAuth0.profilIncomplet(jetonInscription, info);
    }

    /**
     * Étape 1 de complétion : validation du jeton temporaire et émission de l'OTP SMS sur le téléphone malien (+223).
     */
    @Transactional
    public ReponseOtpAuth0 declencherOtpCompleter(String jetonInscription, String telephoneBrut, String ip) {
        limiteurDebitIp.verifierLimite(ip);

        // Vérification de validité du jeton temporaire
        jetonInscriptionService.validerAuth0(jetonInscription);

        String telephone = Telephone.normaliser(telephoneBrut);
        String codeOtp = otpService.emettrePourTelephone(telephone, null);

        return new ReponseOtpAuth0(
                "OTP_ENVOYE",
                telephone,
                "Un code de vérification SMS a été envoyé au numéro " + telephone,
                proprietes.otp().afficherDansReponse() ? codeOtp : null
        );
    }

    /**
     * Étape 2 de complétion : vérification OTP, création ou fusion de compte, association du sous-compte Auth0
     * et ouverture de session authentifiée.
     */
    @Transactional
    public AuthService.Connexion completerEtConnecter(DemandeCompleterAuth0 d, String ip) {
        limiteurDebitIp.verifierLimite(ip);

        Auth0UserInfo info = jetonInscriptionService.validerAuth0(d.jetonInscription());
        String telephone = Telephone.normaliser(d.telephone());

        // Vérification stricte du code OTP
        if (d.codeOtp() == null || d.codeOtp().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-02", "Le code de vérification SMS est obligatoire");
        }
        otpService.verifierPourTelephone(telephone, d.codeOtp().strip());

        // Consommation à usage unique du jeton temporaire
        jetonInscriptionService.consommer(d.jetonInscription());

        Instant maintenant = horloge.instant();
        Utilisateur u;

        // Vérification d'un compte existant avec ce numéro (Fusion de compte)
        var existantOpt = utilisateurs.findByTelephone(telephone);
        if (existantOpt.isPresent()) {
            u = existantOpt.get();

            // Vérifier que ce sub n'est pas déjà rattaché
            if (comptesExternes.existsByFournisseurAndSub(FOURNISSEUR_AUTH0, info.sub())) {
                throw new ErreurMetier(CodeErreur.CONFLIT, "RG-01", "Ce compte Auth0 est déjà associé à un autre profil");
            }

            // Rattachement du compte externe Auth0 au compte existant
            comptesExternes.save(new CompteExterne(FOURNISSEUR_AUTH0, info.sub(), u, info.email(), maintenant));

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

            audit.tracer(u.getId(), "FUSION_COMPTE_AUTH0", null, "telephone=" + telephone + ", sub=" + info.sub());
        } else {
            // Création d'un nouveau compte sans mot de passe initial
            TypeActeur type = d.typeActeur() != null ? d.typeActeur() : TypeActeur.COMMERCANT;
            if (type == TypeActeur.ADMINISTRATEUR) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-01", "Inscription administrateur interdite");
            }

            Role role = roles.findByNom(type.name())
                    .orElseThrow(() -> new IllegalStateException("Rôle absent de la base : " + type));

            String nom = (info.nom() != null && !info.nom().isBlank()) ? info.nom() : "Commerçant Karavan";
            String boutique = (d.nomBoutique() != null && !d.nomBoutique().isBlank())
                    ? d.nomBoutique().strip()
                    : "Boutique " + nom;
            String quartier = (d.quartierBamako() != null && !d.quartierBamako().isBlank())
                    ? d.quartierBamako().strip()
                    : "Grand Marché";

            u = switch (type) {
                case COMMERCANT -> new Commercant(telephone, nom, null, role, maintenant,
                        boutique, null, quartier, null);
                case GROSSISTE -> new Grossiste(telephone, nom, null, role, maintenant,
                        boutique, "084729103M", null);
                case COURTIER -> new Courtier(telephone, nom, null, role, maintenant,
                        boutique, "LT-BKO-2026", null);
                default -> throw new IllegalStateException();
            };

            u.marquerTelephoneVerifie();
            if (info.email() != null && !info.email().isBlank()) {
                u.modifierEmail(info.email().strip().toLowerCase());
            }
            if (info.photoUrl() != null && !info.photoUrl().isBlank()) {
                u.modifierPhoto(info.photoUrl().strip());
            }
            if (!type.exigeKyc()) {
                u.changerStatut(StatutCompte.ACTIF);
            }

            u = utilisateurs.save(u);

            // Création de la ligne compte_externe
            comptesExternes.save(new CompteExterne(FOURNISSEUR_AUTH0, info.sub(), u, info.email(), maintenant));

            audit.tracer(u.getId(), "CREATION_COMPTE_AUTH0", null, "type=" + type + ", telephone=" + telephone);
        }

        return creerSession(u, d.deviceId(), ip, maintenant);
    }

    private AuthService.Connexion creerSession(Utilisateur u, String deviceId, String ip, Instant maintenant) {
        SessionUtilisateur session = sessions.save(new SessionUtilisateur(u.getId(), deviceId, ip, null, maintenant,
                maintenant.plus(proprietes.session().inactivite())));

        List<String> permissions = AuthService.codesPermissions(u);
        boolean estAdmin = u instanceof Administrateur || "ADMIN".equals(u.typeActeur().name());
        Duration accessDuration = estAdmin ? RefreshTokenService.DUREE_ACCESS_ADMIN : RefreshTokenService.DUREE_ACCESS_STANDARD;
        Instant expiration = maintenant.plus(accessDuration);

        String jeton = jwt.generer(u.getId(), session.getId(), u.typeActeur().name(), permissions, maintenant, expiration);
        var nouveauRt = refreshTokenService.creerToken(u.getId(), session.getId(), deviceId, ip, estAdmin);

        return new AuthService.Connexion(jeton, nouveauRt.jetonBrut(), expiration, nouveauRt.expiration(),
                AuthService.profil(u, permissions));
    }
}
