package ml.dogo.identite.domain;

import java.util.EnumSet;
import java.util.Set;
import ml.dogo.shared.domain.MachineEtats;

/** RG-01, RG-03, RG-09. */
public enum StatutCompte implements MachineEtats<StatutCompte> {
    EN_ATTENTE, ACTIF, SUSPENDU, DESACTIVE;

    @Override
    public Set<StatutCompte> suivants() {
        return switch (this) {
            case EN_ATTENTE -> EnumSet.of(ACTIF, SUSPENDU, DESACTIVE);
            case ACTIF -> EnumSet.of(SUSPENDU, DESACTIVE);
            case SUSPENDU -> EnumSet.of(ACTIF, DESACTIVE);
            case DESACTIVE -> EnumSet.noneOf(StatutCompte.class);
        };
    }

    /** RG-09 : un compte suspendu ou désactivé ne peut plus s'authentifier. */
    public boolean peutSAuthentifier() {
        return this == ACTIF || this == EN_ATTENTE;
    }
}
