package ml.dogo.identite.persistence;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import ml.dogo.identite.domain.StatutValidation;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

@Entity
@Table(name = "dossier_kyc")
public class DossierKyc {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "utilisateur_id", nullable = false)
    private Long utilisateurId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutValidation statut = StatutValidation.EN_ATTENTE;

    @Column(name = "date_soumission", nullable = false)
    private Instant dateSoumission;

    @Column(name = "motif_rejet")
    private String motifRejet;

    @OneToMany(cascade = CascadeType.ALL, fetch = FetchType.EAGER)
    @JoinColumn(name = "dossier_id", nullable = false)
    private List<DocumentLegal> documents = new ArrayList<>();

    protected DossierKyc() {
    }

    public DossierKyc(Long utilisateurId, Instant dateSoumission) {
        this.utilisateurId = utilisateurId;
        this.dateSoumission = dateSoumission;
    }

    public void ajouter(DocumentLegal doc) {
        documents.add(doc);
    }

    /** RG-05 : un dossier n'est décidé qu'une fois ; un rejet exige un motif. */
    public void decider(StatutValidation decision, String commentaire) {
        if (statut != StatutValidation.EN_ATTENTE) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-05", "Ce dossier a déjà été décidé");
        }
        if (decision == StatutValidation.EN_ATTENTE) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-05", "La décision doit être APPROUVE ou REJETE");
        }
        if (decision == StatutValidation.REJETE && (commentaire == null || commentaire.isBlank())) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-05", "Un rejet exige un motif");
        }
        this.statut = decision;
        this.motifRejet = decision == StatutValidation.REJETE ? commentaire : null;
    }

    public Long getId() { return id; }
    public Long getUtilisateurId() { return utilisateurId; }
    public StatutValidation getStatut() { return statut; }
    public Instant getDateSoumission() { return dateSoumission; }
    public String getMotifRejet() { return motifRejet; }
    public List<DocumentLegal> getDocuments() { return documents; }
}
