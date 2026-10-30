package ml.dogo.logistique.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * Événement logistique de suivi d'acheminement, correspondant à la classe EvenementLogistique du diagramme UML.
 */
@Entity
@Table(name = "evenement_logistique")
public class EvenementLogistique {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "expedition_id")
    private Long expeditionId;

    @Column(nullable = false)
    private String statut;

    @Column(nullable = false)
    private Instant date;

    @Column(nullable = false)
    private String localisation;

    protected EvenementLogistique() {
    }

    public EvenementLogistique(Long expeditionId, String statut, Instant date, String localisation) {
        this.expeditionId = expeditionId;
        this.statut = statut;
        this.date = date;
        this.localisation = localisation;
    }

    public void notifierEtape() {
    }

    public void tracerPosition() {
    }

    public Long getId() { return id; }
    public Long getExpeditionId() { return expeditionId; }
    public String getStatut() { return statut; }
    public Instant getDate() { return date; }
    public String getLocalisation() { return localisation; }
}
