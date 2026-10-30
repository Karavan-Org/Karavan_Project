package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;
import jakarta.persistence.PrimaryKeyJoinColumn;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.identite.domain.TypeActeur;

@Entity
@Table(name = "commercant")
@DiscriminatorValue("COMMERCANT")
@PrimaryKeyJoinColumn(name = "utilisateur_id")
public class Commercant extends Utilisateur {

    @Column(name = "nom_boutique", nullable = false)
    private String nomBoutique;

    @Column(name = "adresse_livraison")
    private String adresseLivraison;

    @Column(name = "quartier_bamako")
    private String quartierBamako;

    @Column(name = "canal_vente")
    private String canalVente;

    @Column(name = "latitude")
    private Double latitude;

    @Column(name = "longitude")
    private Double longitude;

    protected Commercant() {
    }

    public Commercant(String telephone, String nom, String pinHash, Role role, Instant date, String nomBoutique,
                      String adresseLivraison, String quartierBamako, String canalVente) {
        super(telephone, nom, pinHash, role, date);
        this.nomBoutique = nomBoutique;
        this.adresseLivraison = adresseLivraison;
        this.quartierBamako = quartierBamako;
        this.canalVente = canalVente;
    }

    @Override
    public TypeActeur typeActeur() {
        return TypeActeur.COMMERCANT;
    }

    public String getNomBoutique() { return nomBoutique; }
    public void setNomBoutique(String nomBoutique) { this.nomBoutique = nomBoutique; }

    public String getAdresseLivraison() { return adresseLivraison; }
    public void setAdresseLivraison(String adresseLivraison) { this.adresseLivraison = adresseLivraison; }

    public String getQuartierBamako() { return quartierBamako; }
    public void setQuartierBamako(String quartierBamako) { this.quartierBamako = quartierBamako; }

    public String getCanalVente() { return canalVente; }

    public Double getLatitude() { return latitude; }
    public void setLatitude(Double latitude) { this.latitude = latitude; }

    public Double getLongitude() { return longitude; }
    public void setLongitude(Double longitude) { this.longitude = longitude; }
}
