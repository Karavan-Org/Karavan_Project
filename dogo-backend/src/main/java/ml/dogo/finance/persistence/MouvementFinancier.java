package ml.dogo.finance.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import ml.dogo.finance.domain.TypeMouvement;

/** RG-40 : ligne du journal financier, jamais modifiée ni supprimée (déclencheurs en base). */
@Entity
@Table(name = "mouvement_financier")
public class MouvementFinancier {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "paiement_id", updatable = false)
    private Long paiementId;

    @Column(name = "portefeuille_id", updatable = false)
    private Long portefeuilleId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, updatable = false)
    private TypeMouvement type;

    @Column(nullable = false, updatable = false)
    private BigDecimal montant;

    @Column(name = "date_mouvement", nullable = false, updatable = false)
    private Instant dateMouvement;

    @Column(nullable = false, updatable = false)
    private String reference;

    protected MouvementFinancier() {
    }

    public MouvementFinancier(Long paiementId, Long portefeuilleId, TypeMouvement type, BigDecimal montant,
                              Instant dateMouvement, String reference) {
        this.paiementId = paiementId;
        this.portefeuilleId = portefeuilleId;
        this.type = type;
        this.montant = montant;
        this.dateMouvement = dateMouvement;
        this.reference = reference;
    }

    public Long getId() { return id; }
    public Long getPaiementId() { return paiementId; }
    public Long getPortefeuilleId() { return portefeuilleId; }
    public TypeMouvement getType() { return type; }
    public BigDecimal getMontant() { return montant; }
    public Instant getDateMouvement() { return dateMouvement; }
    public String getReference() { return reference; }
}
