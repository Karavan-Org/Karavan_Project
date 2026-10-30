package ml.dogo.finance.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "frais_plateforme")
public class FraisPlateforme {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "paiement_id", nullable = false, updatable = false)
    private Long paiementId;

    @Column(nullable = false, updatable = false)
    private BigDecimal montant;

    @Column(name = "taux_commission", nullable = false, updatable = false)
    private BigDecimal tauxCommission;

    @Column(name = "date_prelevement", nullable = false, updatable = false)
    private Instant datePrelevement;

    protected FraisPlateforme() {
    }

    public FraisPlateforme(Long paiementId, BigDecimal montant, BigDecimal tauxCommission, Instant datePrelevement) {
        this.paiementId = paiementId;
        this.montant = montant;
        this.tauxCommission = tauxCommission;
        this.datePrelevement = datePrelevement;
    }

    public BigDecimal getMontant() { return montant; }
}
