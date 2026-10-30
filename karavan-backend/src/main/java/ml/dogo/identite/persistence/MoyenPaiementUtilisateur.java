package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import ml.dogo.identite.domain.OperateurMobileMoney;

@Entity
@Table(name = "moyen_paiement_utilisateur")
public class MoyenPaiementUtilisateur {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "utilisateur_id", nullable = false)
    private Long utilisateurId;

    @Column(name = "numero_mobile_money", nullable = false)
    private String numeroMobileMoney;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OperateurMobileMoney operateur;

    @Column(name = "par_defaut", nullable = false)
    private boolean parDefaut;

    protected MoyenPaiementUtilisateur() {
    }

    public MoyenPaiementUtilisateur(Long utilisateurId, String numeroMobileMoney, OperateurMobileMoney operateur,
                                    boolean parDefaut) {
        this.utilisateurId = utilisateurId;
        this.numeroMobileMoney = numeroMobileMoney;
        this.operateur = operateur;
        this.parDefaut = parDefaut;
    }

    public void definirParDefaut(boolean valeur) {
        this.parDefaut = valeur;
    }

    public Long getId() { return id; }
    public Long getUtilisateurId() { return utilisateurId; }
    public String getNumeroMobileMoney() { return numeroMobileMoney; }
    public OperateurMobileMoney getOperateur() { return operateur; }
    public boolean isParDefaut() { return parDefaut; }
}
