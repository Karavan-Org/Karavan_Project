package ml.dogo.finance.domain;

import java.util.EnumSet;
import java.util.Set;
import ml.dogo.shared.domain.MachineEtats;

/** Cycle de vie d'un paiement (RG-33 à RG-36). */
public enum StatutPaiement implements MachineEtats<StatutPaiement> {
    INITIE, EN_ATTENTE, PAYE, ECHOUE, EXPIRE, REMBOURSE;

    @Override
    public Set<StatutPaiement> suivants() {
        return switch (this) {
            case INITIE -> EnumSet.of(EN_ATTENTE, ECHOUE, EXPIRE);
            case EN_ATTENTE -> EnumSet.of(PAYE, ECHOUE, EXPIRE);
            case PAYE -> EnumSet.of(REMBOURSE);
            case ECHOUE, EXPIRE, REMBOURSE -> EnumSet.noneOf(StatutPaiement.class);
        };
    }
}
