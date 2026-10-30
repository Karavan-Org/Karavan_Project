package ml.dogo.catalogue.api;

/**
 * Point d'extension implémenté par le module campagne : le catalogue demande « ce produit est-il engagé dans un groupe
 * OUVERT ? » (RG-15) sans dépendre du module campagne.
 */
public interface EngagementProduit {

    boolean engageDansGroupeOuvert(long produitId);
}
