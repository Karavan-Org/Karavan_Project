package ml.dogo.logistique.domain;

import java.util.EnumSet;
import java.util.Set;
import ml.dogo.shared.domain.MachineEtats;

/**
 * Statut d'expédition correspondant à l'enum StatutExpedition du diagramme UML.
 * Machine d'états stricte :
 * ACHETE -> CHEZ_TRANSITAIRE -> EN_TRANSIT -> ARRIVE
 * avec état exceptionnel de transit : EN_TRANSIT <-> BLOQUE_DOUANE.
 */
public enum StatutExpedition implements MachineEtats<StatutExpedition> {
    ACHETE,
    CHEZ_TRANSITAIRE,
    EN_TRANSIT,
    BLOQUE_DOUANE,
    ARRIVE;

    @Override
    public Set<StatutExpedition> suivants() {
        return switch (this) {
            case ACHETE -> EnumSet.of(CHEZ_TRANSITAIRE);
            case CHEZ_TRANSITAIRE -> EnumSet.of(EN_TRANSIT);
            case EN_TRANSIT -> EnumSet.of(ARRIVE, BLOQUE_DOUANE);
            case BLOQUE_DOUANE -> EnumSet.of(EN_TRANSIT);
            case ARRIVE -> EnumSet.noneOf(StatutExpedition.class);
        };
    }
}

