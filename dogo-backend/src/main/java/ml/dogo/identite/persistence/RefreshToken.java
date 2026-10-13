package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "refresh_token")
public class RefreshToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "token_hash", nullable = false, unique = true, length = 64)
    private String tokenHash;

    @Column(name = "utilisateur_id", nullable = false)
    private Long utilisateurId;

    @Column(name = "session_id")
    private Long sessionId;

    @Column(name = "device_id", length = 120)
    private String deviceId;

    @Column(name = "ip_creation", length = 45)
    private String ipCreation;

    @Column(name = "date_expiration", nullable = false)
    private Instant dateExpiration;

    @Column(nullable = false)
    private boolean revoque;

    @Column(name = "date_revocation")
    private Instant dateRevocation;

    @Column(name = "remplace_par_hash", length = 64)
    private String remplaceParHash;

    @Column(name = "derniere_utilisation")
    private Instant derniereUtilisation;

    @Column(name = "date_creation", nullable = false)
    private Instant dateCreation;

    protected RefreshToken() {
    }

    public RefreshToken(String tokenHash, Long utilisateurId, Long sessionId, String deviceId, String ipCreation,
                        Instant dateCreation, Instant dateExpiration) {
        this.tokenHash = tokenHash;
        this.utilisateurId = utilisateurId;
        this.sessionId = sessionId;
        this.deviceId = deviceId;
        this.ipCreation = ipCreation;
        this.dateCreation = dateCreation;
        this.dateExpiration = dateExpiration;
        this.revoque = false;
    }

    public boolean estValide(Instant maintenant) {
        return !revoque && maintenant.isBefore(dateExpiration);
    }

    public void revoquer(Instant maintenant, String remplacePar) {
        this.revoque = true;
        this.dateRevocation = maintenant;
        this.remplaceParHash = remplacePar;
    }

    public void revoquer(Instant maintenant) {
        revoquer(maintenant, null);
    }

    public void enregistrerUtilisation(Instant maintenant) {
        this.derniereUtilisation = maintenant;
    }

    public Long getId() {
        return id;
    }

    public String getTokenHash() {
        return tokenHash;
    }

    public Long getUtilisateurId() {
        return utilisateurId;
    }

    public Long getSessionId() {
        return sessionId;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public String getIpCreation() {
        return ipCreation;
    }

    public Instant getDateExpiration() {
        return dateExpiration;
    }

    public boolean isRevoque() {
        return revoque;
    }

    public Instant getDateRevocation() {
        return dateRevocation;
    }

    public String getRemplaceParHash() {
        return remplaceParHash;
    }

    public Instant getDerniereUtilisation() {
        return derniereUtilisation;
    }

    public Instant getDateCreation() {
        return dateCreation;
    }
}
