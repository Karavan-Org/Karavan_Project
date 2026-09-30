package ml.dogo.groupeachat.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.groupeachat.domain.StatutGroupe;

/** RG-19 : trace de chaque changement d'état d'un groupe. */
@Entity
@Table(name = "transition_statut_groupe")
public class TransitionStatutGroupe {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "groupe_id", nullable = false)
    private Long groupeId;

    @Enumerated(EnumType.STRING)
    @Column(name = "ancien_statut", nullable = false)
    private StatutGroupe ancienStatut;

    @Enumerated(EnumType.STRING)
    @Column(name = "nouveau_statut", nullable = false)
    private StatutGroupe nouveauStatut;

    @Column(name = "date_transition", nullable = false)
    private Instant dateTransition;

    @Column(nullable = false)
    private String auteur;

    protected TransitionStatutGroupe() {
    }

    public TransitionStatutGroupe(Long groupeId, StatutGroupe ancien, StatutGroupe nouveau, Instant date, String auteur) {
        this.groupeId = groupeId;
        this.ancienStatut = ancien;
        this.nouveauStatut = nouveau;
        this.dateTransition = date;
        this.auteur = auteur;
    }

    public Long getId() { return id; }
    public Long getGroupeId() { return groupeId; }
    public StatutGroupe getAncienStatut() { return ancienStatut; }
    public StatutGroupe getNouveauStatut() { return nouveauStatut; }
    public Instant getDateTransition() { return dateTransition; }
    public String getAuteur() { return auteur; }
}

