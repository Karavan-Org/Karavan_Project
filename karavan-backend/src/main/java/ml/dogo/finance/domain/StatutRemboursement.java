package ml.dogo.finance.domain;

import java.util.EnumSet;
import java.util.Set;
import ml.dogo.shared.domain.MachineEtats;

public enum StatutRemboursement implements MachineEtats<StatutRemboursement> {
    DEMANDE, APPROUVE, REJETE, EXECUTE;

    @Override
    public Set<StatutRemboursement> suivants() {
        return switch (this) {
            case DEMANDE -> EnumSet.of(APPROUVE, REJETE);
            case APPROUVE -> EnumSet.of(EXECUTE);
            case REJETE, EXECUTE -> EnumSet.noneOf(StatutRemboursement.class);
        };
    }
}
