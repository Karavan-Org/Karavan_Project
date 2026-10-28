package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;

/** Compte externe lié à un fournisseur d'identité OAuth2 (ex. Google). */
@Entity
@Table(name = "compte_externe", uniqueConstraints = {
        @UniqueConstraint(name = "uq_compte_externe_fournisseur_sub", columnNames = {"fournisseur", "sub"})
})
public class CompteExterne {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 30)
    private String fournisseur;

    @Column(nullable = false, length = 255)
    private String sub;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "utilisateur_id", nullable = false)
    private Utilisateur utilisateur;

    @Column(length = 255)
    private String email;

    @Column(name = "cree_le", nullable = false)
    private Instant creeLe;

    protected CompteExterne() {
    }

    public CompteExterne(String fournisseur, String sub, Utilisateur utilisateur, String email, Instant creeLe) {
        this.fournisseur = fournisseur;
        this.sub = sub;
        this.utilisateur = utilisateur;
        this.email = email;
        this.creeLe = creeLe;
    }

    public Long getId() { return id; }
    public String getFournisseur() { return fournisseur; }
    public String getSub() { return sub; }
    public Utilisateur getUtilisateur() { return utilisateur; }
    public String getEmail() { return email; }
    public Instant getCreeLe() { return creeLe; }
}

