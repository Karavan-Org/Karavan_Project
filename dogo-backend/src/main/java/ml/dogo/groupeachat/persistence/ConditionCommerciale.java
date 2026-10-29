package ml.dogo.groupeachat.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "condition_commerciale")
public class ConditionCommerciale {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "groupe_id", nullable = false, updatable = false)
    private Long groupeId;

    @Column(name = "delai_livraison_jours", nullable = false)
    private int delaiLivraisonJours;

    @Column(name = "politique_annulation")
    private String politiqueAnnulation;

    @Column(name = "quantite_min_par_commercant", nullable = false)
    private int quantiteMinParCommercant = 1;

    protected ConditionCommerciale() {
    }

    public ConditionCommerciale(Long groupeId, int delaiLivraisonJours, String politiqueAnnulation,
                                int quantiteMinParCommercant) {
        this.groupeId = groupeId;
        appliquer(delaiLivraisonJours, politiqueAnnulation, quantiteMinParCommercant);
    }

    public final void appliquer(int delaiLivraisonJours, String politiqueAnnulation, int quantiteMinParCommercant) {
        this.delaiLivraisonJours = delaiLivraisonJours;
        this.politiqueAnnulation = politiqueAnnulation;
        this.quantiteMinParCommercant = quantiteMinParCommercant;
    }

    public Long getId() { return id; }
    public Long getGroupeId() { return groupeId; }
    public int getDelaiLivraisonJours() { return delaiLivraisonJours; }
    public String getPolitiqueAnnulation() { return politiqueAnnulation; }
    public int getQuantiteMinParCommercant() { return quantiteMinParCommercant; }
}

