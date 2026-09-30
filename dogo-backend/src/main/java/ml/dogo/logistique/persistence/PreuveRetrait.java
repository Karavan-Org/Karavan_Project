package ml.dogo.logistique.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** RG-55 : preuve écrite dans la même transaction que la collecte. */
@Entity
@Table(name = "preuve_retrait")
public class PreuveRetrait {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "commande_id", nullable = false, updatable = false)
    private Long commandeId;

    @Column(nullable = false, updatable = false)
    private String type;

    @Column(updatable = false)
    private String fichier;

    @Column(name = "date_retrait", nullable = false, updatable = false)
    private Instant dateRetrait;

    protected PreuveRetrait() {
    }

    public PreuveRetrait(Long commandeId, String type, String fichier, Instant dateRetrait) {
        this.commandeId = commandeId;
        this.type = type;
        this.fichier = fichier;
        this.dateRetrait = dateRetrait;
    }

    public Long getId() { return id; }
    public String getType() { return type; }
}
