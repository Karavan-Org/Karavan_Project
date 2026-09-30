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

/** RG-32 : une ligne par changement de statut. */
@Entity
@Table(name = "historique_participation")
public class HistoriqueParticipation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "participation_id", nullable = false, updatable = false)
    private Long participationId;

    @Enumerated(EnumType.STRING)
    @Column(name = "ancien_statut", updatable = false)
    private StatutParticipation ancienStatut;

    @Enumerated(EnumType.STRING)
    @Column(name = "nouveau_statut", nullable = false, updatable = false)
    private StatutParticipation nouveauStatut;

    @Column(name = "date_evenement", nullable = false, updatable = false)
    private Instant dateEvenement;

    protected HistoriqueParticipation() {
    }

    public HistoriqueParticipation(Long participationId, StatutParticipation ancien, StatutParticipation nouveau,
                                   Instant date) {
        this.participationId = participationId;
        this.ancienStatut = ancien;
        this.nouveauStatut = nouveau;
        this.dateEvenement = date;
    }

    public StatutParticipation getAncienStatut() { return ancienStatut; }
    public StatutParticipation getNouveauStatut() { return nouveauStatut; }
    public Instant getDateEvenement() { return dateEvenement; }
}
