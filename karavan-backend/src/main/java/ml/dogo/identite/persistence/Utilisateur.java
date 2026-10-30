package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.DiscriminatorColumn;
import jakarta.persistence.DiscriminatorType;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Inheritance;
import jakarta.persistence.InheritanceType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.identite.domain.RegleAcces;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.TypeActeur;

/** Compte utilisateur. Les quatre acteurs héritent de cette classe (généralisation du diagramme de classes). */
@Entity
@Table(name = "utilisateur")
@Inheritance(strategy = InheritanceType.JOINED)
@DiscriminatorColumn(name = "type_acteur", discriminatorType = DiscriminatorType.STRING)
public abstract class Utilisateur {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String telephone;

    @Column(nullable = false)
    private String nom;

    @Column(name = "email")
    private String email;

    @Column(name = "mot_de_passe_hash")
    private String motDePasseHash;

    /** RG-07b : mot de passe attribué par un tiers, à remplacer avant toute autre action */
    @Column(name = "mot_de_passe_provisoire", nullable = false)
    private boolean motDePasseProvisoire;

    @Column(nullable = false)
    private String langue = "fr";

    @Column(name = "photo_url")
    private String photoUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "statut_compte", nullable = false)
    private StatutCompte statutCompte = StatutCompte.EN_ATTENTE;

    @Column(name = "telephone_verifie", nullable = false)
    private boolean telephoneVerifie;

    @Column(name = "tentatives_echecs", nullable = false)
    private int tentativesEchecs;

    @Column(name = "verrouille_jusqua")
    private Instant verrouilleJusqua;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "role_id", nullable = false)
    private Role role;

    @Column(name = "date_creation", nullable = false)
    private Instant dateCreation;

    protected Utilisateur() {
    }

    protected Utilisateur(String telephone, String nom, String motDePasseHash, Role role, Instant dateCreation) {
        this.telephone = telephone;
        this.nom = nom;
        this.motDePasseHash = motDePasseHash;
        this.role = role;
        this.dateCreation = dateCreation;
    }

    public abstract TypeActeur typeActeur();

    // ---- comportements (RG-01, RG-03, RG-07, RG-09)

    public void reinitialiserEchecs() {
        this.tentativesEchecs = 0;
        this.verrouilleJusqua = null;
    }

    public void reinitialiserEchecsPin() {
        reinitialiserEchecs();
    }

    public void verifierNonVerrouille(Instant maintenant) {
        RegleAcces.verifierNonVerrouille(verrouilleJusqua, maintenant);
    }

    public void modifierIdentite(String nom, String langue) {
        if (nom != null && !nom.isBlank()) {
            this.nom = nom.strip();
        }
        if (langue != null && !langue.isBlank()) {
            this.langue = langue;
        }
    }

    public void modifierPhoto(String photoUrl) {
        this.photoUrl = photoUrl;
    }

    public void marquerTelephoneVerifie() {
        this.telephoneVerifie = true;
    }

    public void changerStatut(StatutCompte cible) {
        this.statutCompte = statutCompte.verifierTransition(cible, "RG-09");
    }

    public boolean estActif() {
        return statutCompte == StatutCompte.ACTIF;
    }

    /** Le titulaire choisit lui-même son mot de passe : il cesse d'être provisoire. */
    public void changerMotDePasse(String nouveauHash) {
        if (nouveauHash != null && !nouveauHash.isBlank()) {
            this.motDePasseHash = nouveauHash;
            this.motDePasseProvisoire = false;
        }
    }

    /** RG-07b : le mot de passe actuel a été fixé par un tiers et devra être changé à la prochaine connexion. */
    public void imposerChangementMotDePasse() {
        this.motDePasseProvisoire = true;
    }

    public boolean isMotDePasseProvisoire() { return motDePasseProvisoire; }

    public Long getId() { return id; }
    public String getTelephone() { return telephone; }
    public String getNom() { return nom; }
    public String getEmail() { return email; }
    public void modifierEmail(String email) { this.email = email; }
    public boolean hasMotDePasse() { return motDePasseHash != null && !motDePasseHash.isBlank(); }
    public String getMotDePasseHash() { return motDePasseHash; }
    public String getPinHash() { return motDePasseHash; }
    public String getLangue() { return langue; }
    public String getPhotoUrl() { return photoUrl; }
    public StatutCompte getStatutCompte() { return statutCompte; }
    public boolean isTelephoneVerifie() { return telephoneVerifie; }
    public Role getRole() { return role; }
    public Instant getDateCreation() { return dateCreation; }
}
