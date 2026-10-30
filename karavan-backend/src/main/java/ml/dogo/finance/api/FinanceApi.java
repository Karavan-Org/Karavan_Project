package ml.dogo.finance.api;

/** Ce que les autres modules ont le droit de demander au module finance. */
public interface FinanceApi {

    /**
     * RG-38 / RG-55 : libère le séquestre du paiement de cette participation vers le portefeuille du Courtier
     * (montant moins frais de plateforme), dans la transaction de l'appelant. Refusé si le séquestre est gelé (RG-62)
     * ou déjà traité.
     */
    void libererSequestre(long participationId);
}
