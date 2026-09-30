package ml.dogo.finance.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** RG-35 : callback brut de l'opérateur, conservé tel que reçu. L'identifiant opérateur est unique. */
@Entity
@Table(name = "transaction_mobile_money")
public class TransactionMobileMoney {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "paiement_id", nullable = false, updatable = false)
    private Long paiementId;

    @Column(name = "tx_id", nullable = false, updatable = false)
    private String txId;

    @Column(nullable = false, updatable = false)
    private String operateur;

    @Column(name = "callback_brut", columnDefinition = "TEXT", updatable = false)
    private String callbackBrut;

    @Column(name = "date_callback", updatable = false)
    private Instant dateCallback;

    protected TransactionMobileMoney() {
    }

    public TransactionMobileMoney(Long paiementId, String txId, String operateur, String callbackBrut, Instant date) {
        this.paiementId = paiementId;
        this.txId = txId;
        this.operateur = operateur;
        this.callbackBrut = callbackBrut;
        this.dateCallback = date;
    }

    public Long getId() { return id; }
    public Long getPaiementId() { return paiementId; }
    public String getTxId() { return txId; }
}
