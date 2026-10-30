package ml.dogo.participation.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;

/** RG-29 : prix, produit et cible figés à la réservation. Jamais modifié ensuite. */
@Entity
@Table(name = "snapshot_groupe")
public class SnapshotGroupe {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "participation_id", nullable = false, updatable = false)
    private Long participationId;

    @Column(name = "produit_fige", nullable = false, updatable = false)
    private String produitFige;

    @Column(name = "prix_fige", nullable = false, updatable = false)
    private BigDecimal prixFige;

    @Column(name = "frais_unitaire_fige", nullable = false, updatable = false)
    private BigDecimal fraisUnitaireFige;

    @Column(name = "quantite_cible_figee", nullable = false, updatable = false)
    private int quantiteCibleFigee;

    @Column(name = "date_fige", nullable = false, updatable = false)
    private Instant dateFige;

    protected SnapshotGroupe() {
    }

    public SnapshotGroupe(Long participationId, String produitFige, BigDecimal prixFige, BigDecimal fraisUnitaireFige,
                          int quantiteCibleFigee, Instant dateFige) {
        this.participationId = participationId;
        this.produitFige = produitFige;
        this.prixFige = prixFige;
        this.fraisUnitaireFige = fraisUnitaireFige;
        this.quantiteCibleFigee = quantiteCibleFigee;
        this.dateFige = dateFige;
    }

    public Long getParticipationId() { return participationId; }
    public String getProduitFige() { return produitFige; }
    public BigDecimal getPrixFige() { return prixFige; }
    public BigDecimal getFraisUnitaireFige() { return fraisUnitaireFige; }
    public int getQuantiteCibleFigee() { return quantiteCibleFigee; }
}
