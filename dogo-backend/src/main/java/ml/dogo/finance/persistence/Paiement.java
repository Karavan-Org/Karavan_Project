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
import ml.dogo.finance.domain.RegleFinance;
import ml.dogo.finance.domain.StatutPaiement;

/** La colonne générée {@code cle_vivante} (un seul paiement en cours par participation) n'est pas mappée. */
@Entity
@Table(name = "paiement")
public class Paiement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "participation_id", nullable = false, updatable = false)
    private Long participationId;

    @Column(name = "moyen_paiement_id", updatable = false)
    private Long moyenPaiementId;

    @Column(nullable = false, updatable = false)
    private BigDecimal montant;

    @Column(name = "montant_rembourse", nullable = false)
    private BigDecimal montantRembourse = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutPaiement statut = StatutPaiement.INITIE;

    @Column(name = "cle_idempotence", nullable = false, updatable = false)
    private String cleIdempotence;

    @Column(name = "date_initiation", nullable = false, updatable = false)
    private Instant dateInitiation;

    @Column(name = "date_maj", nullable = false)
    private Instant dateMaj;

    protected Paiement() {
    }

    public Paiement(Long participationId, Long moyenPaiementId, BigDecimal montant, String cleIdempotence,
                    Instant maintenant) {
        this.participationId = participationId;
        this.moyenPaiementId = moyenPaiementId;
        this.montant = montant;
        this.cleIdempotence = cleIdempotence;
        this.dateInitiation = maintenant;
        this.dateMaj = maintenant;
    }

    /** RG-33 à RG-36 : évolution du statut par la machine à états. */
    public void changerStatut(StatutPaiement cible, Instant maintenant) {
        this.statut = statut.verifierTransition(cible, "RG-35");
        this.dateMaj = maintenant;
    }

    /** RG-58 : enregistre un remboursement ; le paiement passe à REMBOURSE quand il est intégralement rendu. */
    public void enregistrerRemboursement(BigDecimal montantRembourse, Instant maintenant) {
        RegleFinance.verifierMontantRemboursable(montant, this.montantRembourse, montantRembourse);
        this.montantRembourse = this.montantRembourse.add(montantRembourse);
        if (this.montantRembourse.compareTo(montant) == 0) {
            changerStatut(StatutPaiement.REMBOURSE, maintenant);
        } else {
            this.dateMaj = maintenant;
        }
    }

    public BigDecimal restantRemboursable() {
        return montant.subtract(montantRembourse);
    }

    public Long getId() { return id; }
    public Long getParticipationId() { return participationId; }
    public Long getMoyenPaiementId() { return moyenPaiementId; }
    public BigDecimal getMontant() { return montant; }
    public BigDecimal getMontantRembourse() { return montantRembourse; }
    public StatutPaiement getStatut() { return statut; }
    public String getCleIdempotence() { return cleIdempotence; }
    public Instant getDateInitiation() { return dateInitiation; }
    public Instant getDateMaj() { return dateMaj; }
}
