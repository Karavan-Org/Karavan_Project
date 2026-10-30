package ml.dogo.finance.domain;

import java.util.EnumSet;
import java.util.Set;
import ml.dogo.shared.domain.MachineEtats;

/** Séquestre : les fonds sont bloqués puis libérés au retrait, ou restitués au commerçant (RG-36, RG-38, RG-59). */
public enum StatutSequestre implements MachineEtats<StatutSequestre> {
    BLOQUE, LIBERE, RESTITUE;

    @Override
    public Set<StatutSequestre> suivants() {
        return this == BLOQUE ? EnumSet.of(LIBERE, RESTITUE) : EnumSet.noneOf(StatutSequestre.class);
    }
}
