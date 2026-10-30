package ml.dogo.litige.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * Preuve à l'appui d'un litige (photo, rapport de conformité), correspondant à PreuveLitige du diagramme UML.
 */
@Entity
@Table(name = "preuve_litige")
public class PreuveLitige {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "litige_id", nullable = false)
    private Long litigeId;

    @Column(nullable = false)
    private String type;

    @Column(nullable = false)
    private String fichier;

    @Column(nullable = false)
    private Instant date;

    protected PreuveLitige() {
    }

    public PreuveLitige(Long litigeId, String type, String fichier, Instant date) {
        this.litigeId = litigeId;
        this.type = type;
        this.fichier = fichier;
        this.date = date;
    }

    public void uploader() {
    }

    public boolean verifierIntegrite() {
        return fichier != null && !fichier.isBlank();
    }

    public Long getId() { return id; }
    public Long getLitigeId() { return litigeId; }
    public String getType() { return type; }
    public String getFichier() { return fichier; }
    public Instant getDate() { return date; }
}
