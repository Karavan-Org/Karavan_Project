package ml.dogo.finance.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;

/**
 * Taux de change multi-devises (XOF, RMB/CNY, USD), correspondant à la classe TauxDeChange du diagramme UML.
 */
@Entity
@Table(name = "taux_de_change")
public class TauxDeChange {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "devise_source", nullable = false, length = 10)
    private String deviseSource;

    @Column(name = "devise_cible", nullable = false, length = 10)
    private String deviseCible;

    @Column(nullable = false, precision = 12, scale = 4)
    private BigDecimal taux;

    @Column(name = "date_mise_a_jour", nullable = false)
    private Instant date;

    protected TauxDeChange() {
    }

    public TauxDeChange(String deviseSource, String deviseCible, BigDecimal taux, Instant date) {
        this.deviseSource = deviseSource;
        this.deviseCible = deviseCible;
        this.taux = taux;
        this.date = date;
    }

    public BigDecimal convertir(BigDecimal montant) {
        if (montant == null || taux == null) {
            return BigDecimal.ZERO;
        }
        return montant.multiply(taux).setScale(2, RoundingMode.HALF_UP);
    }

    public void actualiserTaux(BigDecimal nouveauTaux, Instant maintenant) {
        this.taux = nouveauTaux;
        this.date = maintenant;
    }

    public Long getId() { return id; }
    public String getDeviseSource() { return deviseSource; }
    public String getDeviseCible() { return deviseCible; }
    public BigDecimal getTaux() { return taux; }
    public Instant getDate() { return date; }
}
