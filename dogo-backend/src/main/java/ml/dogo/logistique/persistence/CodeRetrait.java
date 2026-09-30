package ml.dogo.logistique.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * RG-53 / RG-54 : code unique par commande. Le PIN n'est jamais stocké en clair (RG-71). Les compteurs et drapeaux
 * (tentatives, utilisé, bloqué) ne sont écrits que par des requêtes SQL atomiques.
 */
@Entity
@Table(name = "code_retrait")
public class CodeRetrait {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "commande_id", nullable = false, updatable = false)
    private Long commandeId;

    @Column(name = "pin_hash", nullable = false, updatable = false)
    private String pinHash;

    @Column(name = "qr_token", nullable = false, updatable = false)
    private String qrToken;

    @Column(nullable = false, updatable = false)
    private Instant expiration;

    @Column(insertable = false, updatable = false)
    private int tentatives;

    @Column(insertable = false, updatable = false)
    private boolean utilise;

    @Column(insertable = false, updatable = false)
    private boolean bloque;

    @Column(name = "date_creation", nullable = false, updatable = false)
    private Instant dateCreation;

    protected CodeRetrait() {
    }

    public CodeRetrait(Long commandeId, String pinHash, String qrToken, Instant expiration, Instant dateCreation) {
        this.commandeId = commandeId;
        this.pinHash = pinHash;
        this.qrToken = qrToken;
        this.expiration = expiration;
        this.dateCreation = dateCreation;
    }

    public Long getId() { return id; }
    public Long getCommandeId() { return commandeId; }
    public String getPinHash() { return pinHash; }
    public String getQrToken() { return qrToken; }
    public Instant getExpiration() { return expiration; }
    public int getTentatives() { return tentatives; }
    public boolean isUtilise() { return utilise; }
    public boolean isBloque() { return bloque; }
}
