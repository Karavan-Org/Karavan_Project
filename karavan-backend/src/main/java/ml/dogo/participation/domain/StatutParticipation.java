package ml.dogo.participation.domain;

import java.util.EnumSet;
import java.util.Set;
import ml.dogo.shared.domain.MachineEtats;

/** Cycle de vie d'une participation (RG-26 à RG-32). */
public enum StatutParticipation implements MachineEtats<StatutParticipation> {
    DEMANDEE, RESERVEE, CONFIRMEE, ANNULEE, EXPIREE;

    @Override
    public Set<StatutParticipation> suivants() {
        return switch (this) {
            case DEMANDEE -> EnumSet.of(RESERVEE, ANNULEE, EXPIREE);
            case RESERVEE -> EnumSet.of(CONFIRMEE, ANNULEE, EXPIREE);
            case CONFIRMEE -> EnumSet.of(ANNULEE);
            case ANNULEE, EXPIREE -> EnumSet.noneOf(StatutParticipation.class);
        };
    }

    /** Une participation active occupe une place dans le groupe (RG-26). */
    public boolean active() {
        return this == DEMANDEE || this == RESERVEE || this == CONFIRMEE;
    }
}
