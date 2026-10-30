package ml.dogo.groupeachat.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "validation_groupe")
public class ValidationGroupe {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "groupe_id", nullable = false)
    private Long groupeId;

    /** NULL : décision prise par un administrateur supprimé depuis (V26) */
    @Column(name = "administrateur_id")
    private Long administrateurId;

    @Column(nullable = false)
    private String decision;

    @Column(name = "date_decision", nullable = false)
    private Instant dateDecision;

    private String commentaire;

    protected ValidationGroupe() {
    }

    public ValidationGroupe(Long groupeId, Long administrateurId, String decision, Instant dateDecision,
                            String commentaire) {
        this.groupeId = groupeId;
        this.administrateurId = administrateurId;
        this.decision = decision;
        this.dateDecision = dateDecision;
        this.commentaire = commentaire;
    }

    public Long getId() { return id; }
    public String getDecision() { return decision; }
}

