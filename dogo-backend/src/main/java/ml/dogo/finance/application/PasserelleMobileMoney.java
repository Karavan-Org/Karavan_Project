package ml.dogo.finance.application;

import java.math.BigDecimal;

/**
 * Port vers les opérateurs Mobile Money (Orange Money, Moov Money, Wave). La version de démonstration se contente de
 * journaliser ; un vrai fournisseur la remplacera sans toucher au reste du module.
 */
public interface PasserelleMobileMoney {

    /** Envoie la demande de débit au téléphone du payeur. Le résultat arrive plus tard par callback signé (RG-35). */
    void demanderDebit(String reference, String numero, String operateur, BigDecimal montant);

    /** Rend de l'argent au payeur (RG-59). */
    void rembourser(String reference, String numero, String operateur, BigDecimal montant);

    /** Verse de l'argent sur le compte Mobile Money du Courtier (RG-41). */
    void verser(String reference, String numero, String operateur, BigDecimal montant);
}
