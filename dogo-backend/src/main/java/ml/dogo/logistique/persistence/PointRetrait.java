package ml.dogo.logistique.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "point_retrait")
public class PointRetrait {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String nom;

    @Column(nullable = false)
    private String adresse;

    private String quartier;

    protected PointRetrait() {
    }

    public PointRetrait(String nom, String adresse, String quartier) {
        this.nom = nom;
        this.adresse = adresse;
        this.quartier = quartier;
    }

    public Long getId() { return id; }
    public String getNom() { return nom; }
    public String getAdresse() { return adresse; }
    public String getQuartier() { return quartier; }
}
