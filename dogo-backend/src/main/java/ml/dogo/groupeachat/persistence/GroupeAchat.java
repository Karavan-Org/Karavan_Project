package ml.dogo.groupeachat.persistence;

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
import ml.dogo.groupeachat.domain.StatutGroupe;

/**
 * Groupe d'achat. Le statut et les quantités confirmée / réservée ne sont jamais écrits par l'entité
 * ({@code updatable = false}) : ils changent uniquement par des requêtes SQL conditionnelles atomiques (RG-19, RG-23),
 * pour qu'un enregistrement d'entité ne puisse pas écraser une mise à jour concurrente.
 */
@Entity
@Table(name = "groupe_achat")
public class GroupeAchat {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "courtier_id", nullable = false, updatable = false)
    private Long courtierId;

    @Column(name = "grossiste_id", nullable = false, updatable = false)
    private Long grossisteId;

    @Column(name = "produit_id", nullable = false, updatable = false)
    private Long produitId;

    @Column(name = "quantite_cible", nullable = false)
    private int quantiteCible;

    @Column(name = "quantite_confirmee", insertable = false, updatable = false)
    private int quantiteConfirmee;

    @Column(name = "quantite_reservee", insertable = false, updatable = false)
    private int quantiteReservee;

    @Column(name = "prix_unitaire", nullable = false)
    private BigDecimal prixUnitaire;

    @Column(name = "date_ouverture", nullable = false)
    private Instant dateOuverture;

    @Column(name = "date_limite", nullable = false)
    private Instant dateLimite;

    @Enumerated(EnumType.STRING)
    @Column(insertable = false, updatable = false)
    private StatutGroupe statut = StatutGroupe.BROUILLON;

    @Column(name = "disponibilite_validee", nullable = false)
    private boolean disponibiliteValidee;

    protected GroupeAchat() {
    }

    public GroupeAchat(Long courtierId, Long grossisteId, Long produitId, int quantiteCible, BigDecimal prixUnitaire,
                       Instant dateOuverture, Instant dateLimite) {
        this.courtierId = courtierId;
        this.grossisteId = grossisteId;
        this.produitId = produitId;
        this.quantiteCible = quantiteCible;
        this.prixUnitaire = prixUnitaire;
        this.dateOuverture = dateOuverture;
        this.dateLimite = dateLimite;
    }

    /** Modification d'un brouillon (RG-17) : après publication, la grille et la cible sont figées (RG-20). */
    public void modifierBrouillon(int quantiteCible, BigDecimal prixUnitaire, Instant dateLimite) {
        this.quantiteCible = quantiteCible;
        this.prixUnitaire = prixUnitaire;
        this.dateLimite = dateLimite;
        this.disponibiliteValidee = false;
    }

    public void validerDisponibilite() {
        this.disponibiliteValidee = true;
    }

    public void reinitialiserDisponibilite() {
        this.disponibiliteValidee = false;
    }

    public void ouvrir(Instant maintenant) {
        this.dateOuverture = maintenant;
    }

    public Long getId() { return id; }
    public Long getCourtierId() { return courtierId; }
    public Long getGrossisteId() { return grossisteId; }
    public Long getProduitId() { return produitId; }
    public int getQuantiteCible() { return quantiteCible; }
    public int getQuantiteConfirmee() { return quantiteConfirmee; }
    public int getQuantiteReservee() { return quantiteReservee; }
    public BigDecimal getPrixUnitaire() { return prixUnitaire; }
    public Instant getDateOuverture() { return dateOuverture; }
    public Instant getDateLimite() { return dateLimite; }
    public StatutGroupe getStatut() { return statut; }
    public boolean isDisponibiliteValidee() { return disponibiliteValidee; }
}

