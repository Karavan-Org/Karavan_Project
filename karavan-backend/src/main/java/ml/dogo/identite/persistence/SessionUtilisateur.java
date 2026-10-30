package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "session_utilisateur")
public class SessionUtilisateur {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "utilisateur_id", nullable = false)
    private Long utilisateurId;

    @Column(name = "device_id")
    private String deviceId;

    private String ip;

    private String empreinte;

    @Column(name = "date_creation", nullable = false)
    private Instant dateCreation;

    @Column(name = "derniere_activite", nullable = false)
    private Instant derniereActivite;

    @Column(name = "date_expiration", nullable = false)
    private Instant dateExpiration;

    @Column(nullable = false)
    private boolean invalidee;

    protected SessionUtilisateur() {
    }

    public SessionUtilisateur(Long utilisateurId, String deviceId, String ip, String empreinte, Instant maintenant,
                              Instant dateExpiration) {
        this.utilisateurId = utilisateurId;
        this.deviceId = deviceId;
        this.ip = ip;
        this.empreinte = empreinte;
        this.dateCreation = maintenant;
        this.derniereActivite = maintenant;
        this.dateExpiration = dateExpiration;
    }

    public void invalider() {
        this.invalidee = true;
    }

    public boolean estValide(Instant maintenant) {
        return !invalidee && maintenant.isBefore(dateExpiration);
    }

    /** RG-08 : l'activité repousse l'expiration. On n'écrit qu'après 5 minutes pour ne pas charger la base. */
    public boolean prolonger(Instant maintenant, Instant nouvelleExpiration) {
        if (maintenant.isBefore(derniereActivite.plusSeconds(300))) {
            return false;
        }
        this.derniereActivite = maintenant;
        this.dateExpiration = nouvelleExpiration;
        return true;
    }

    public Long getId() { return id; }
    public Long getUtilisateurId() { return utilisateurId; }
    public Instant getDateExpiration() { return dateExpiration; }
    public boolean isInvalidee() { return invalidee; }
}
