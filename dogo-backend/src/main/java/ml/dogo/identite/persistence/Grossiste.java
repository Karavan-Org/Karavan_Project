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
@Table(name = "grossiste")
@DiscriminatorValue("GROSSISTE")
@PrimaryKeyJoinColumn(name = "utilisateur_id")
public class Grossiste extends Utilisateur {

    @Column(name = "nom_boutique_marche", nullable = false)
    private String nomBoutiqueMarche;

    @Column(name = "numero_nif")
    private String numeroNif;

    @Column(name = "registre_commerce")
    private String registreCommerce;

    @Column(name = "note_fiabilite", nullable = false)
    private BigDecimal noteFiabilite = BigDecimal.ZERO;

    protected Grossiste() {
    }

    public Grossiste(String telephone, String nom, String pinHash, Role role, Instant date, String nomBoutiqueMarche,
                     String numeroNif, String registreCommerce) {
        super(telephone, nom, pinHash, role, date);
        this.nomBoutiqueMarche = nomBoutiqueMarche;
        this.numeroNif = numeroNif;
        this.registreCommerce = registreCommerce;
    }

    @Override
    public TypeActeur typeActeur() {
        return TypeActeur.GROSSISTE;
    }

    public String getNomBoutiqueMarche() { return nomBoutiqueMarche; }
    public String getNumeroNif() { return numeroNif; }
    public String getRegistreCommerce() { return registreCommerce; }
    public BigDecimal getNoteFiabilite() { return noteFiabilite; }
}
