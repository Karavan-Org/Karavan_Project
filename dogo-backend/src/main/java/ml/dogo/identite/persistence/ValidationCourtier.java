package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.identite.domain.StatutValidation;

/**
 * Validation d'un professionnel (Courtier / Grossiste), correspondant à l'entité ValidationCourtier du diagramme de classes.
 */
@Entity
@Table(name = "validation_compte")
public class ValidationCourtier {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "dossier_id", nullable = false)
    private Long dossierId;

    @Column(name = "administrateur_id", nullable = false)
    private Long administrateurId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutValidation decision;

    @Column(name = "date_decision", nullable = false)
    private Instant dateDecision;

    private String commentaire;

    protected ValidationCourtier() {
    }

    public ValidationCourtier(Long dossierId, Long administrateurId, StatutValidation decision, Instant dateDecision,
                              String commentaire) {
        this.dossierId = dossierId;
        this.administrateurId = administrateurId;
        this.decision = decision;
        this.dateDecision = dateDecision;
        this.commentaire = commentaire;
    }

    public void approuverCourtier() {
        this.decision = StatutValidation.APPROUVE;
    }

    public void rejeterCourtier() {
        this.decision = StatutValidation.REJETE;
    }

    public Long getId() { return id; }
    public Long getDossierId() { return dossierId; }
    public Long getAdministrateurId() { return administrateurId; }
    public StatutValidation getDecision() { return decision; }
    public Instant getDateDecision() { return dateDecision; }
    public String getCommentaire() { return commentaire; }
}
