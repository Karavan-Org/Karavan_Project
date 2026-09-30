package ml.dogo.logistique.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.logistique.domain.StatutExpedition;

/**
 * Expédition d'un convoi de marchandises, correspondant à la classe Expedition du diagramme UML.
 */
@Entity
@Table(name = "expedition")
public class Expedition {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "groupe_id")
    private Long groupeId;

    @Column(nullable = false, unique = true)
    private String reference;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutExpedition statut = StatutExpedition.ACHETE;

    @Column(name = "date_depart")
    private Instant dateDepart;

    @Column(name = "transporteur")
    private String transporteur;

    protected Expedition() {
    }

    public Expedition(Long groupeId, String reference, StatutExpedition statut, Instant dateDepart, String transporteur) {
        this.groupeId = groupeId;
        this.reference = reference;
        this.statut = statut != null ? statut : StatutExpedition.ACHETE;
        this.dateDepart = dateDepart;
        this.transporteur = transporteur;
    }

    public void lancerTransit() {
        this.statut = StatutExpedition.EN_TRANSIT;
    }

    public void declarerDouane() {
        this.statut = StatutExpedition.BLOQUE_DOUANE;
    }

    public Long getId() { return id; }
    public Long getGroupeId() { return groupeId; }
    public String getReference() { return reference; }
    public StatutExpedition getStatut() { return statut; }
    public Instant getDateDepart() { return dateDepart; }
    public String getTransporteur() { return transporteur; }
}
