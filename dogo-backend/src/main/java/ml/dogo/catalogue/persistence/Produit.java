package ml.dogo.catalogue.persistence;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

@Entity
@Table(name = "produit")
public class Produit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "grossiste_id", nullable = false, updatable = false)
    private Long grossisteId;

    @Column(name = "categorie_id", nullable = false)
    private Long categorieId;

    @Column(name = "nom_produit", nullable = false)
    private String nom;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "photo_url")
    private String photoUrl;

    @Column(name = "pays_origine")
    private String paysOrigine;

    @OneToMany(cascade = CascadeType.ALL, fetch = FetchType.EAGER, orphanRemoval = false)
    @JoinColumn(name = "produit_id", nullable = false)
    @OrderBy("id ASC")
    private List<VarianteProduit> variantes = new ArrayList<>();

    protected Produit() {
    }

    public Produit(Long grossisteId, Long categorieId, String nom, String description, String photoUrl, String paysOrigine,
                   List<VarianteProduit> variantes) {
        if (variantes == null || variantes.isEmpty()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-12", "Un produit a au moins une variante");
        }
        this.grossisteId = grossisteId;
        this.categorieId = categorieId;
        this.nom = nom;
        this.description = description;
        this.photoUrl = photoUrl;
        this.paysOrigine = paysOrigine;
        this.variantes.addAll(variantes);
    }

    public Produit(Long grossisteId, Long categorieId, String nom, String description, String paysOrigine,
                   List<VarianteProduit> variantes) {
        this(grossisteId, categorieId, nom, description, null, paysOrigine, variantes);
    }

    public void uploaderPhoto(String photoUrl) {
        this.photoUrl = photoUrl;
    }

    public void modifier(String nom, String description, String paysOrigine) {
        if (nom != null && !nom.isBlank()) {
            this.nom = nom.strip();
        }
        if (description != null) {
            this.description = description;
        }
        if (paysOrigine != null) {
            this.paysOrigine = paysOrigine;
        }
    }

    public void ajouterVariante(VarianteProduit v) {
        variantes.add(v);
    }

    public Long getId() { return id; }
    public Long getGrossisteId() { return grossisteId; }
    public Long getCategorieId() { return categorieId; }
    public String getNom() { return nom; }
    public String getDescription() { return description; }
    public String getPhotoUrl() { return photoUrl; }
    public String getPaysOrigine() { return paysOrigine; }
    public List<VarianteProduit> getVariantes() { return variantes; }
}
