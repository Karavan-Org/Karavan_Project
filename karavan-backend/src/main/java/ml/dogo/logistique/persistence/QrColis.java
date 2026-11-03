package ml.dogo.logistique.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * Entité QR Colis : jeton opaque unique associé à une expédition / convoi de marchandises.
 * Le jeton brut (préfixé 'KVC.') n'est jamais conservé en base de données : seul son hash SHA-256 est stocké.
 */
@Entity
@Table(name = "qr_colis")
public class QrColis {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "expedition_id", nullable = false)
    private Long expeditionId;

    @Column(name = "token_hash", nullable = false, unique = true)
    private String tokenHash;

    @Column(name = "code_court_hash", nullable = false, unique = true)
    private String codeCourtHash;

    @Column(nullable = false)
    private String statut = "ACTIF";

    @Column(nullable = false)
    private Instant expiration;

    @Column(name = "date_creation", nullable = false, updatable = false)
    private Instant dateCreation;

    @Column(name = "date_utilisation")
    private Instant dateUtilisation;

    @Column(name = "valide_par_id")
    private Long valideParId;

    @Column(nullable = false)
    private int tentatives = 0;

    protected QrColis() {
    }

    public QrColis(Long expeditionId, String tokenHash, String codeCourtHash, Instant expiration, Instant dateCreation) {
        this.expeditionId = expeditionId;
        this.tokenHash = tokenHash;
        this.codeCourtHash = codeCourtHash;
        this.expiration = expiration;
        this.dateCreation = dateCreation;
        this.statut = "ACTIF";
        this.tentatives = 0;
    }

    public Long getId() { return id; }
    public Long getExpeditionId() { return expeditionId; }
    public String getTokenHash() { return tokenHash; }
    public String getCodeCourtHash() { return codeCourtHash; }
    public String getStatut() { return statut; }
    public Instant getExpiration() { return expiration; }
    public Instant getDateCreation() { return dateCreation; }
    public Instant getDateUtilisation() { return dateUtilisation; }
    public Long getValideParId() { return valideParId; }
    public int getTentatives() { return tentatives; }

    public boolean isActif() { return "ACTIF".equalsIgnoreCase(statut); }
    public boolean isUtilise() { return "UTILISE".equalsIgnoreCase(statut); }
    public boolean isAnnule() { return "ANNULE".equalsIgnoreCase(statut); }
}
