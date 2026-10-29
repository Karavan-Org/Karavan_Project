package ml.dogo.groupeachat.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import ml.dogo.groupeachat.domain.CalculPrix;

@Entity
@Table(name = "grille_tarifaire")
public class GrilleTarifaire {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "groupe_id", nullable = false, updatable = false)
    private Long groupeId;

    @Column(name = "prix_marchandise", nullable = false)
    private BigDecimal prixMarchandise;

    @Column(nullable = false)
    private BigDecimal transport;

    @Column(name = "frais_plateforme", nullable = false)
    private BigDecimal fraisPlateforme;

    @Column(nullable = false)
    private BigDecimal douane;

    @Column(nullable = false)
    private BigDecimal autres;

    @Column(nullable = false)
    private String devise = "XOF";

    @Column(name = "taux_commission", nullable = false)
    private BigDecimal tauxCommission;

    protected GrilleTarifaire() {
    }

    public GrilleTarifaire(Long groupeId, CalculPrix.Composantes c, BigDecimal tauxCommission) {
        this.groupeId = groupeId;
        appliquer(c, tauxCommission);
    }

    public final void appliquer(CalculPrix.Composantes c, BigDecimal tauxCommission) {
        this.prixMarchandise = c.marchandise();
        this.transport = c.transport();
        this.fraisPlateforme = c.fraisPlateforme();
        this.douane = c.douane();
        this.autres = c.autres();
        this.tauxCommission = tauxCommission;
    }

    public Long getId() { return id; }
    public Long getGroupeId() { return groupeId; }
    public BigDecimal getPrixMarchandise() { return prixMarchandise; }
    public BigDecimal getTransport() { return transport; }
    public BigDecimal getFraisPlateforme() { return fraisPlateforme; }
    public BigDecimal getDouane() { return douane; }
    public BigDecimal getAutres() { return autres; }
    public String getDevise() { return devise; }
    public BigDecimal getTauxCommission() { return tauxCommission; }
}

