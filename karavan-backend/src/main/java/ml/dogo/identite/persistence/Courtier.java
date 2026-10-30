package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;
import jakarta.persistence.PrimaryKeyJoinColumn;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import ml.dogo.identite.domain.TypeActeur;

@Entity
@Table(name = "courtier")
@DiscriminatorValue("COURTIER")
@PrimaryKeyJoinColumn(name = "utilisateur_id")
public class Courtier extends Utilisateur {

    @Column(name = "nom_societe_import", nullable = false)
    private String nomSocieteImport;

    @Column(name = "licence_transit")
    private String licenceTransit;

    @Column(name = "adresse_depot")
    private String adresseDepot;

    @Column(name = "note_fiabilite", nullable = false)
    private BigDecimal noteFiabilite = BigDecimal.ZERO;

    @Column(name = "latitude")
    private Double latitude;

    @Column(name = "longitude")
    private Double longitude;

    protected Courtier() {
    }

    public Courtier(String telephone, String nom, String pinHash, Role role, Instant date, String nomSocieteImport,
                    String licenceTransit, String adresseDepot) {
        super(telephone, nom, pinHash, role, date);
        this.nomSocieteImport = nomSocieteImport;
        this.licenceTransit = licenceTransit;
        this.adresseDepot = adresseDepot;
    }

    @Override
    public TypeActeur typeActeur() {
        return TypeActeur.COURTIER;
    }

    public String getNomSocieteImport() { return nomSocieteImport; }
    public void setNomSocieteImport(String nomSocieteImport) { this.nomSocieteImport = nomSocieteImport; }

    public String getLicenceTransit() { return licenceTransit; }
    public String getAdresseDepot() { return adresseDepot; }
    public void setAdresseDepot(String adresseDepot) { this.adresseDepot = adresseDepot; }

    public BigDecimal getNoteFiabilite() { return noteFiabilite; }

    public Double getLatitude() { return latitude; }
    public void setLatitude(Double latitude) { this.latitude = latitude; }

    public Double getLongitude() { return longitude; }
    public void setLongitude(Double longitude) { this.longitude = longitude; }
}
