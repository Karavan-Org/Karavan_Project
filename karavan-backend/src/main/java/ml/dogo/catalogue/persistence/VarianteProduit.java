package ml.dogo.catalogue.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

@Entity
@Table(name = "variante_produit")
public class VarianteProduit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Colonne portée par la relation de Produit ; ici en lecture seule pour retrouver le produit d'une variante. */
    @Column(name = "produit_id", insertable = false, updatable = false)
    private Long produitId;

    @Column(nullable = false, unique = true)
    private String sku;

    private String taille;

    private String couleur;

    @Column(name = "qte_disponible", nullable = false)
    private int qteDisponible;

    protected VarianteProduit() {
    }

    public VarianteProduit(String sku, String taille, String couleur, int qteDisponible) {
        this.sku = sku;
        this.taille = taille;
        this.couleur = couleur;
        definirStock(qteDisponible);
    }

    /** RG-13 : le stock n'est jamais négatif. */
    public final void definirStock(int quantite) {
        if (quantite < 0) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-13", "La quantité disponible ne peut pas être négative");
        }
        this.qteDisponible = quantite;
    }

    public Long getId() { return id; }
    public Long getProduitId() { return produitId; }
    public String getSku() { return sku; }
    public String getTaille() { return taille; }
    public String getCouleur() { return couleur; }
    public int getQteDisponible() { return qteDisponible; }
}
