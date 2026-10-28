package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.DiscriminatorValue;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.PrimaryKeyJoinColumn;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.domain.TypeActeur;

@Entity
@Table(name = "administrateur")
@DiscriminatorValue("ADMINISTRATEUR")
@PrimaryKeyJoinColumn(name = "utilisateur_id")
public class Administrateur extends Utilisateur {

    @Column(name = "matricule_agent", nullable = false, unique = true)
    private String matriculeAgent;

    @Enumerated(EnumType.STRING)
    @Column(name = "role_administratif", nullable = false)
    private RoleAdministratif roleAdministratif;

    @Column(name = "code_securite_hash")
    private String codeSecuriteHash;

    @Column(name = "code_securite_date")
    private Instant codeSecuriteDate;

    protected Administrateur() {
    }

    public Administrateur(String telephone, String nom, String pinHash, Role role, Instant date,
                          String matriculeAgent, RoleAdministratif roleAdministratif) {
        super(telephone, nom, pinHash, role, date);
        this.matriculeAgent = matriculeAgent;
        this.roleAdministratif = roleAdministratif;
    }

    @Override
    public TypeActeur typeActeur() {
        return TypeActeur.ADMINISTRATEUR;
    }

    public String getMatriculeAgent() { return matriculeAgent; }
    public RoleAdministratif getRoleAdministratif() { return roleAdministratif; }

    public boolean hasCodeSecurite() {
        return codeSecuriteHash != null && !codeSecuriteHash.isBlank();
    }

    public void definirCodeSecurite(String hash, Instant date) {
        this.codeSecuriteHash = hash;
        this.codeSecuriteDate = date;
    }

    public String getCodeSecuriteHash() { return codeSecuriteHash; }
    public Instant getCodeSecuriteDate() { return codeSecuriteDate; }
}
