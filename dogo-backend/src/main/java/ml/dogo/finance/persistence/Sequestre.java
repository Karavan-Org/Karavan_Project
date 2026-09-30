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
import ml.dogo.finance.domain.StatutSequestre;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

@Entity
@Table(name = "sequestre")
public class Sequestre {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "paiement_id", nullable = false, updatable = false)
    private Long paiementId;

    @Column(name = "montant_bloque", nullable = false, updatable = false)
    private BigDecimal montantBloque;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutSequestre statut = StatutSequestre.BLOQUE;

    @Column(nullable = false)
    private boolean gele;

    @Column(name = "date_blocage", nullable = false, updatable = false)
    private Instant dateBlocage;

    @Column(name = "date_liberation")
    private Instant dateLiberation;

    protected Sequestre() {
    }

    public Sequestre(Long paiementId, BigDecimal montantBloque, Instant dateBlocage) {
        this.paiementId = paiementId;
        this.montantBloque = montantBloque;
        this.dateBlocage = dateBlocage;
    }

    /** RG-38 : libération vers le Courtier, une seule fois, jamais sur un séquestre gelé (RG-62). */
    public void liberer(Instant maintenant) {
        if (gele) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-62", "Séquestre gelé : un litige est en cours");
        }
        this.statut = statut.verifierTransition(StatutSequestre.LIBERE, "RG-36");
        this.dateLiberation = maintenant;
    }

    /** RG-59 : restitution au Commerçant tant que le séquestre est bloqué. */
    public void restituer(Instant maintenant) {
        this.statut = statut.verifierTransition(StatutSequestre.RESTITUE, "RG-59");
        this.dateLiberation = maintenant;
    }

    public Long getId() { return id; }
    public Long getPaiementId() { return paiementId; }
    public BigDecimal getMontantBloque() { return montantBloque; }
    public StatutSequestre getStatut() { return statut; }
    public boolean isGele() { return gele; }
    public Instant getDateBlocage() { return dateBlocage; }
    public Instant getDateLiberation() { return dateLiberation; }
}
