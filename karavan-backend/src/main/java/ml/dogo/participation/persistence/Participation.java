package ml.dogo.participation.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.participation.domain.StatutParticipation;

/** La colonne générée {@code cle_active} (unicité RG-26) n'est pas mappée : elle est calculée par la base. */
@Entity
@Table(name = "participation")
public class Participation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "groupe_id", nullable = false, updatable = false)
    private Long groupeId;

    @Column(name = "commercant_id", nullable = false, updatable = false)
    private Long commercantId;

    @Column(name = "variante_id", nullable = false, updatable = false)
    private Long varianteId;

    @Column(name = "quantite_demandee", nullable = false, updatable = false)
    private int quantite;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutParticipation statut = StatutParticipation.DEMANDEE;

    @Column(name = "date_creation", nullable = false, updatable = false)
    private Instant dateCreation;

    @Column(name = "date_expiration_reservation")
    private Instant dateExpirationReservation;

    protected Participation() {
    }

    public Participation(Long groupeId, Long commercantId, Long varianteId, int quantite, Instant dateCreation,
                         Instant dateExpirationReservation) {
        this.groupeId = groupeId;
        this.commercantId = commercantId;
        this.varianteId = varianteId;
        this.quantite = quantite;
        this.dateCreation = dateCreation;
        this.dateExpirationReservation = dateExpirationReservation;
    }

    /** RG-26 à RG-32 : toute évolution passe par la machine à états. Renvoie l'ancien statut pour l'historique. */
    public StatutParticipation changerStatut(StatutParticipation cible) {
        StatutParticipation ancien = statut;
        this.statut = statut.verifierTransition(cible, "RG-26");
        return ancien;
    }

    public Long getId() { return id; }
    public Long getGroupeId() { return groupeId; }
    public Long getCommercantId() { return commercantId; }
    public Long getVarianteId() { return varianteId; }
    public int getQuantite() { return quantite; }
    public StatutParticipation getStatut() { return statut; }
    public Instant getDateCreation() { return dateCreation; }
    public Instant getDateExpirationReservation() { return dateExpirationReservation; }
}
