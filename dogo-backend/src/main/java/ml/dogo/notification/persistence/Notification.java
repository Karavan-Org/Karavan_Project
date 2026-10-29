package ml.dogo.notification.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import ml.dogo.notification.domain.StatutNotification;

@Entity
@Table(name = "notification")
public class Notification {

    public enum Canal { SMS, PUSH }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "utilisateur_id", nullable = false)
    private Long utilisateurId;

    @Column(nullable = false, length = 500)
    private String contenu;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Canal canal;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private StatutNotification statut;

    @Column(nullable = false)
    private int tentatives;

    @Column(name = "date_creation", nullable = false)
    private Instant dateCreation;

    protected Notification() {
    }

    public Notification(Long utilisateurId, String contenu, Canal canal, StatutNotification statut, int tentatives,
                        Instant dateCreation) {
        this.utilisateurId = utilisateurId;
        this.contenu = contenu;
        this.canal = canal;
        this.statut = statut;
        this.tentatives = tentatives;
        this.dateCreation = dateCreation;
    }

    /** RG-70 : nouvelle tentative d'envoi d'une notification en échec. */
    public void enregistrerTentative(boolean succes) {
        this.tentatives++;
        this.statut = succes ? StatutNotification.ENVOYEE : StatutNotification.ECHOUEE;
    }

    /**
     * Lue dans l'application : vaut aussi pour une notification dont le SMS a échoué (sinon elle resterait
     * « non lue » pour toujours) ; elle n'est alors plus renvoyée par SMS, son destinataire l'ayant vue.
     */
    public void marquerLue() {
        if (statut != StatutNotification.LUE) {
            this.statut = StatutNotification.LUE;
        }
    }

    public Long getId() { return id; }
    public Long getUtilisateurId() { return utilisateurId; }
    public String getContenu() { return contenu; }
    public Canal getCanal() { return canal; }
    public StatutNotification getStatut() { return statut; }
    public int getTentatives() { return tentatives; }
    public Instant getDateCreation() { return dateCreation; }
}
