package ml.dogo.litige.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.litige.domain.StatutLitige;

/**
 * Litige commercial sur une commande, correspondant à la classe Litige du diagramme UML.
 */
@Entity
@Table(name = "litige")
public class Litige {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "commande_id", nullable = false)
    private Long commandeId;

    @Column(nullable = false, length = 1000)
    private String motif;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutLitige statut = StatutLitige.OUVERT;

    @Column(name = "date_ouverture", nullable = false)
    private Instant dateOuverture;

    @Column(name = "date_resolution")
    private Instant dateResolution;

    protected Litige() {
    }

    public Litige(Long commandeId, String motif, Instant dateOuverture) {
        this.commandeId = commandeId;
        this.motif = motif;
        this.dateOuverture = dateOuverture;
        this.statut = StatutLitige.OUVERT;
    }

    public void ouvrirDossier() {
        this.statut = StatutLitige.OUVERT;
    }

    public void cloturer() {
        this.statut = StatutLitige.RESOLU;
        this.dateResolution = Instant.now();
    }

    public void statuer(StatutLitige decision) {
        this.statut = decision;
        if (decision == StatutLitige.RESOLU || decision == StatutLitige.REJETE) {
            this.dateResolution = Instant.now();
        }
    }

    public Long getId() { return id; }
    public Long getCommandeId() { return commandeId; }
    public String getMotif() { return motif; }
    public StatutLitige getStatut() { return statut; }
    public Instant getDateOuverture() { return dateOuverture; }
    public Instant getDateResolution() { return dateResolution; }
}
