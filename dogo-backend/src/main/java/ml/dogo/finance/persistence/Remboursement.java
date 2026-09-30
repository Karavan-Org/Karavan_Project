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
import ml.dogo.finance.domain.MotifRemboursement;
import ml.dogo.finance.domain.StatutRemboursement;

@Entity
@Table(name = "remboursement")
public class Remboursement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "paiement_id", nullable = false, updatable = false)
    private Long paiementId;

    @Column(nullable = false, updatable = false)
    private BigDecimal montant;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutRemboursement statut = StatutRemboursement.DEMANDE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, updatable = false)
    private MotifRemboursement motif;

    @Column(name = "approuve_par")
    private Long approuvePar;

    @Column(name = "date_demande", nullable = false, updatable = false)
    private Instant dateDemande;

    @Column(name = "date_maj", nullable = false)
    private Instant dateMaj;

    protected Remboursement() {
    }

    public Remboursement(Long paiementId, BigDecimal montant, MotifRemboursement motif, Instant maintenant) {
        this.paiementId = paiementId;
        this.montant = montant;
        this.motif = motif;
        this.dateDemande = maintenant;
        this.dateMaj = maintenant;
    }

    /** RG-57 : DEMANDE → APPROUVE → EXECUTE, ou DEMANDE → REJETE. {@code adminId} est nul pour une approbation automatique. */
    public void approuver(Long adminId, Instant maintenant) {
        this.statut = statut.verifierTransition(StatutRemboursement.APPROUVE, "RG-57");
        this.approuvePar = adminId;
        this.dateMaj = maintenant;
    }

    public void rejeter(Long adminId, Instant maintenant) {
        this.statut = statut.verifierTransition(StatutRemboursement.REJETE, "RG-57");
        this.approuvePar = adminId;
        this.dateMaj = maintenant;
    }

    public void marquerExecute(Instant maintenant) {
        this.statut = statut.verifierTransition(StatutRemboursement.EXECUTE, "RG-57");
        this.dateMaj = maintenant;
    }

    public Long getId() { return id; }
    public Long getPaiementId() { return paiementId; }
    public BigDecimal getMontant() { return montant; }
    public StatutRemboursement getStatut() { return statut; }
    public MotifRemboursement getMotif() { return motif; }
    public Long getApprouvePar() { return approuvePar; }
    public Instant getDateDemande() { return dateDemande; }
}
