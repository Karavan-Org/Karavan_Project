package ml.dogo.identite.application;

import java.time.Clock;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.domain.RegleAcces;
import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.Telephone;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.RoleRepository;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Création des comptes administrateurs : réservée à l'administrateur principal (TECHNIQUE, créé par la migration V26),
 * pas d'inscription publique.
 */
@Service
public class AdministrateurService {

    private final UtilisateurRepository utilisateurs;
    private final RoleRepository roles;
    private final PasswordEncoder encodeur;
    private final AuditApi audit;
    private final Clock horloge;

    public AdministrateurService(UtilisateurRepository utilisateurs, RoleRepository roles, PasswordEncoder encodeur,
                                 AuditApi audit, Clock horloge) {
        this.utilisateurs = utilisateurs;
        this.roles = roles;
        this.encodeur = encodeur;
        this.audit = audit;
        this.horloge = horloge;
    }

    /**
     * Appelée par l'administrateur principal (TECHNIQUE). Il attribue une fonction (VALIDATION, FINANCE, SUPPORT,
     * LOGISTIQUE) et un mot de passe provisoire, que le nouvel administrateur devra changer à sa première connexion.
     */
    @Transactional
    public long creerParAdministrateur(long parAdminId, String telephone, String nom, String email, String pin,
                                       String matricule, RoleAdministratif role) {
        boolean technique = utilisateurs.findById(parAdminId)
                .map(u -> u instanceof Administrateur a && a.getRoleAdministratif() == RoleAdministratif.TECHNIQUE)
                .orElse(false);
        if (!technique) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-06",
                    "Seul l'administrateur principal peut créer un administrateur");
        }
        if (role == RoleAdministratif.TECHNIQUE) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-06",
                    "La plateforme n'a qu'un administrateur principal : choisissez la fonction Validation, Finance, Support ou Logistique");
        }
        Administrateur a = creer(parAdminId, telephone, nom, pin, matricule, role);
        if (email != null && !email.isBlank()) {
            a.modifierEmail(email.strip().toLowerCase());
        }
        a.imposerChangementMotDePasse();
        return a.getId();
    }

    /** Création sans contrôle d'appelant ni mot de passe provisoire : jeux de données des tests d'intégration. */
    @Transactional
    public long creerInitial(String telephone, String nom, String pin, String matricule, RoleAdministratif role) {
        return creer(null, telephone, nom, pin, matricule, role).getId();
    }

    private Administrateur creer(Long parAdminId, String telephoneBrut, String nom, String pin, String matricule,
                                 RoleAdministratif role) {
        String telephone = Telephone.normaliser(telephoneBrut);
        RegleAcces.verifierFormatPin(pin);
        if (role == null || nom == null || nom.isBlank() || matricule == null || matricule.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-06", "Nom, matricule et rôle sont obligatoires");
        }
        if (utilisateurs.existsByTelephone(telephone)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-01", "Ce numéro de téléphone est déjà utilisé");
        }
        var roleBase = roles.findByNom("ADMINISTRATEUR")
                .orElseThrow(() -> new IllegalStateException("Rôle ADMINISTRATEUR absent de la base"));
        Administrateur a = new Administrateur(telephone, nom.strip(), encodeur.encode(pin), roleBase,
                horloge.instant(), matricule.strip(), role);
        a.marquerTelephoneVerifie();
        a.changerStatut(StatutCompte.ACTIF);
        a = utilisateurs.save(a);
        audit.tracer(parAdminId, "ADMINISTRATEUR_CREE", null, "id=" + a.getId() + ", role=" + role);
        return a;
    }
}
