package ml.dogo.groupeachat.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** Étape d'acheminement signalée par le grossiste qui porte le groupe (suivi du colis). */
@Entity
@Table(name = "etape_acheminement")
public class EtapeAcheminement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "groupe_id", nullable = false)
    private Long groupeId;

    @Column(nullable = false, length = 80)
    private String etape;

    @Column(length = 500)
    private String commentaire;

    @Column(name = "date_signalee", nullable = false)
    private Instant dateSignalee;

    @Column(name = "auteur_id", nullable = false)
    private Long auteurId;

    protected EtapeAcheminement() {
    }

    public EtapeAcheminement(Long groupeId, String etape, String commentaire, Instant dateSignalee, Long auteurId) {
        this.groupeId = groupeId;
        this.etape = etape;
        this.commentaire = commentaire;
        this.dateSignalee = dateSignalee;
        this.auteurId = auteurId;
    }

    public Long getId() { return id; }
    public Long getGroupeId() { return groupeId; }
    public String getEtape() { return etape; }
    public String getCommentaire() { return commentaire; }
    public Instant getDateSignalee() { return dateSignalee; }
    public Long getAuteurId() { return auteurId; }
}
