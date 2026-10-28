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

    /** NULL : groupe porté par le grossiste du produit, sans courtier. */
    @Column(name = "courtier_id", updatable = false)
    private Long courtierId;

    @Column(name = "grossiste_id", nullable = false, updatable = false)
    private Long grossisteId;

    @Column(name = "produit_id", nullable = false, updatable = false)
    private Long produitId;

    @Column(length = 120)
    private String titre;

    /** Code ISO (2 lettres) du pays d'origine de la marchandise pour l'import (FK vers pays). */
    @Column(name = "pays_origine_code", length = 2)
    private String paysOrigineCode;

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

    public GroupeAchat(Long courtierId, Long grossisteId, Long produitId, String titre, String paysOrigineCode,
                       int quantiteCible, BigDecimal prixUnitaire, Instant dateOuverture, Instant dateLimite) {
        this.courtierId = courtierId;
        this.titre = titre;
        this.grossisteId = grossisteId;
        this.produitId = produitId;
        this.paysOrigineCode = paysOrigineCode != null ? paysOrigineCode.trim().toUpperCase() : null;
        this.quantiteCible = quantiteCible;
        this.prixUnitaire = prixUnitaire;
        this.dateOuverture = dateOuverture;
        this.dateLimite = dateLimite;
    }

    public GroupeAchat(Long courtierId, Long grossisteId, Long produitId, String titre, int quantiteCible,
                       BigDecimal prixUnitaire, Instant dateOuverture, Instant dateLimite) {
        this(courtierId, grossisteId, produitId, titre, null, quantiteCible, prixUnitaire, dateOuverture, dateLimite);
    }

    /** Modification d'un brouillon (RG-17) : après publication, la grille et la cible sont figées (RG-20). */
    public void modifierBrouillon(String titre, String paysOrigineCode, int quantiteCible, BigDecimal prixUnitaire, Instant dateLimite) {
        this.titre = titre;
        if (paysOrigineCode != null && !paysOrigineCode.isBlank()) {
            this.paysOrigineCode = paysOrigineCode.trim().toUpperCase();
        }
        this.quantiteCible = quantiteCible;
        this.prixUnitaire = prixUnitaire;
        this.dateLimite = dateLimite;
        this.disponibiliteValidee = false;
    }

    public void modifierBrouillon(String titre, int quantiteCible, BigDecimal prixUnitaire, Instant dateLimite) {
        modifierBrouillon(titre, this.paysOrigineCode, quantiteCible, prixUnitaire, dateLimite);
    }

    public void assignerPaysOrigine(String paysOrigineCode) {
        this.paysOrigineCode = paysOrigineCode != null ? paysOrigineCode.trim().toUpperCase() : null;
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
    /** Celui qui pilote le groupe : son courtier, ou à défaut le grossiste du produit. */
    public Long getPorteurId() { return courtierId != null ? courtierId : grossisteId; }
    public boolean estPorteParGrossiste() { return courtierId == null; }
    public String getTitre() { return titre; }
    public String getPaysOrigineCode() { return paysOrigineCode; }
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
