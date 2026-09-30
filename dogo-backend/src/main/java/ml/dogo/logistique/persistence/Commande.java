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
import ml.dogo.logistique.domain.StatutCommande;

/** RG-44 : une commande par participation confirmée. */
@Entity
@Table(name = "commande")
public class Commande {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "participation_id", nullable = false, updatable = false)
    private Long participationId;

    @Column(name = "groupe_id", nullable = false, updatable = false)
    private Long groupeId;

    @Column(name = "commercant_id", nullable = false, updatable = false)
    private Long commercantId;

    @Column(name = "point_retrait_id")
    private Long pointRetraitId;

    @Column(nullable = false, updatable = false)
    private int quantite;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutCommande statut = StatutCommande.CREEE;

    @Column(name = "date_creation", nullable = false, updatable = false)
    private Instant dateCreation;

    protected Commande() {
    }

    public Commande(Long participationId, Long groupeId, Long commercantId, int quantite, Instant dateCreation) {
        this.participationId = participationId;
        this.groupeId = groupeId;
        this.commercantId = commercantId;
        this.quantite = quantite;
        this.dateCreation = dateCreation;
    }

    /** RG-44, RG-50 : le statut n'évolue que par la machine à états. */
    public void changerStatut(StatutCommande cible) {
        this.statut = statut.verifierTransition(cible, "RG-44");
    }

    public void affecterPointRetrait(Long pointRetraitId) {
        this.pointRetraitId = pointRetraitId;
    }

    public Long getId() { return id; }
    public Long getParticipationId() { return participationId; }
    public Long getGroupeId() { return groupeId; }
    public Long getCommercantId() { return commercantId; }
    public Long getPointRetraitId() { return pointRetraitId; }
    public int getQuantite() { return quantite; }
    public StatutCommande getStatut() { return statut; }
    public Instant getDateCreation() { return dateCreation; }
}
