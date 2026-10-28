package ml.dogo.groupeachat.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Table de référence des pays partenaires pour l'import groupé Karavan.
 */
@Entity
@Table(name = "pays")
public class Pays {

    @Id
    @Column(name = "code_iso", length = 2, nullable = false)
    private String codeIso;

    @Column(name = "code_iso_3", length = 3, unique = true)
    private String codeIso3;

    @Column(name = "nom_fr", length = 100, nullable = false)
    private String nomFr;

    @Column(nullable = false)
    private Double latitude;

    @Column(nullable = false)
    private Double longitude;

    @Column(nullable = false)
    private boolean actif = true;

    protected Pays() {
    }

    public Pays(String codeIso, String codeIso3, String nomFr, Double latitude, Double longitude, boolean actif) {
        this.codeIso = codeIso != null ? codeIso.trim().toUpperCase() : null;
        this.codeIso3 = codeIso3 != null ? codeIso3.trim().toUpperCase() : null;
        this.nomFr = nomFr;
        this.latitude = latitude;
        this.longitude = longitude;
        this.actif = actif;
    }

    public String getCodeIso() {
        return codeIso;
    }

    public String getCodeIso3() {
        return codeIso3;
    }

    public String getNomFr() {
        return nomFr;
    }

    public Double getLatitude() {
        return latitude;
    }

    public Double getLongitude() {
        return longitude;
    }

    public boolean isActif() {
        return actif;
    }

    public void setActif(boolean actif) {
        this.actif = actif;
    }
}

