package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.identite.domain.RegleAcces;

@Entity
@Table(name = "code_otp")
public class CodeOtp {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Nul si le compte a été supprimé (inscription abandonnée remplacée) : le code reste compté par numéro. */
    @Column(name = "utilisateur_id")
    private Long utilisateurId;

    /** Numéro destinataire : base du plafond d'envoi par téléphone (RG-02). */
    @Column(length = 20)
    private String telephone;

    @Column(name = "code_hash", nullable = false)
    private String codeHash;

    @Column(nullable = false)
    private Instant expiration;

    @Column(nullable = false)
    private int tentatives;

    @Column(nullable = false)
    private boolean utilise;

    @Column(name = "date_creation", nullable = false)
    private Instant dateCreation;

    protected CodeOtp() {
    }

    public CodeOtp(Long utilisateurId, String telephone, String codeHash, Instant expiration, Instant dateCreation) {
        this.utilisateurId = utilisateurId;
        this.telephone = telephone;
        this.codeHash = codeHash;
        this.expiration = expiration;
        this.dateCreation = dateCreation;
    }

    /** RG-02 : lève une erreur si le code est expiré, déjà utilisé ou épuisé en tentatives. */
    public void verifierUtilisable(int maxTentatives, Instant maintenant) {
        RegleAcces.verifierOtpUtilisable(utilise, expiration, tentatives, maxTentatives, maintenant);
    }

    public void consommer() {
        this.utilise = true;
    }

    public Long getId() { return id; }
    public Long getUtilisateurId() { return utilisateurId; }
    public String getTelephone() { return telephone; }
    public String getCodeHash() { return codeHash; }
    public Instant getExpiration() { return expiration; }
    public Instant getDateCreation() { return dateCreation; }
    public int getTentatives() { return tentatives; }
    public boolean isUtilise() { return utilise; }
}
