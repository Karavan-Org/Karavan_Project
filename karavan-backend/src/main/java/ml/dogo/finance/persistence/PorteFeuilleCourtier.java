package ml.dogo.finance.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;

/**
 * Portefeuille d'un Courtier, correspondant à la classe PorteFeuilleCourtier du diagramme UML.
 * Les soldes ne sont jamais écrits par l'entité : ils changent uniquement par des requêtes SQL
 * conditionnelles, pour qu'aucune lecture périmée n'écrase un mouvement concurrent (RG-41).
 */
@Entity
@Table(name = "portefeuille")
public class PorteFeuilleCourtier {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "courtier_id", nullable = false, updatable = false)
    private Long courtierId;

    @Column(name = "solde_bloque", insertable = false, updatable = false)
    private BigDecimal soldeBloque;

    @Column(name = "solde_disponible", insertable = false, updatable = false)
    private BigDecimal soldeDisponible;

    @Column(insertable = false, updatable = false)
    private String devise;

    protected PorteFeuilleCourtier() {
    }

    public PorteFeuilleCourtier(Long courtierId, String devise) {
        this.courtierId = courtierId;
        this.devise = devise;
        this.soldeBloque = BigDecimal.ZERO;
        this.soldeDisponible = BigDecimal.ZERO;
    }

    public boolean verifierSolde(BigDecimal montant) {
        return soldeDisponible != null && soldeDisponible.compareTo(montant) >= 0;
    }

    public Long getId() { return id; }
    public Long getCourtierId() { return courtierId; }
    public BigDecimal getSoldeBloque() { return soldeBloque; }
    public BigDecimal getSoldeDisponible() { return soldeDisponible; }
    public String getDevise() { return devise; }
}
