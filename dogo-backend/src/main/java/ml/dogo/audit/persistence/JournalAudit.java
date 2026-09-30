package ml.dogo.audit.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "journal_audit")
public class JournalAudit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "acteur_id")
    private Long acteurId;

    @Column(nullable = false)
    private String action;

    @Column(columnDefinition = "TEXT")
    private String avant;

    @Column(columnDefinition = "TEXT")
    private String apres;

    @Column(name = "date_audit", nullable = false)
    private Instant dateAudit;

    @Column(name = "hash_precedent", nullable = false, length = 64)
    private String hashPrecedent;

    @Column(nullable = false, length = 64)
    private String hash;

    protected JournalAudit() {
    }

    public JournalAudit(Long acteurId, String action, String avant, String apres, Instant dateAudit,
                        String hashPrecedent, String hash) {
        this.acteurId = acteurId;
        this.action = action;
        this.avant = avant;
        this.apres = apres;
        this.dateAudit = dateAudit;
        this.hashPrecedent = hashPrecedent;
        this.hash = hash;
    }

    public Long getId() { return id; }
    public Long getActeurId() { return acteurId; }
    public String getAction() { return action; }
    public String getAvant() { return avant; }
    public String getApres() { return apres; }
    public Instant getDateAudit() { return dateAudit; }
    public String getHashPrecedent() { return hashPrecedent; }
    public String getHash() { return hash; }
}
