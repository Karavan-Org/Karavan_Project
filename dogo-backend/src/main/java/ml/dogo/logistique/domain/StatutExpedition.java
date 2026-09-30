package ml.dogo.logistique.domain;

/**
 * Statut d'expédition correspondant à l'enum StatutExpedition du diagramme UML.
 */
public enum StatutExpedition {
    ACHETE,
    CHEZ_TRANSITAIRE,
    EN_TRANSIT,
    BLOQUE_DOUANE,
    ARRIVE
}
