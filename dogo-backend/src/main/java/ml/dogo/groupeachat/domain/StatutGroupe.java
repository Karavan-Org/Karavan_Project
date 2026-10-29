package ml.dogo.groupeachat.domain;

import java.util.EnumSet;
import java.util.Set;
import ml.dogo.shared.domain.MachineEtats;

/** Cycle de vie d'un groupe d'achat (RG-17 à RG-25). */
public enum StatutGroupe implements MachineEtats<StatutGroupe> {
    BROUILLON, EN_VALIDATION, OUVERT, OBJECTIF_ATTEINT, EN_EXPEDITION, LIVRE, TERMINE, ANNULE, ECHOUE;

    @Override
    public Set<StatutGroupe> suivants() {
        return switch (this) {
            case BROUILLON -> EnumSet.of(EN_VALIDATION, ANNULE);
            case EN_VALIDATION -> EnumSet.of(OUVERT, BROUILLON, ANNULE);
            case OUVERT -> EnumSet.of(OBJECTIF_ATTEINT, ECHOUE, ANNULE);
            case OBJECTIF_ATTEINT -> EnumSet.of(EN_EXPEDITION);
            case EN_EXPEDITION -> EnumSet.of(LIVRE);
            case LIVRE -> EnumSet.of(TERMINE);
            case TERMINE, ANNULE, ECHOUE -> EnumSet.noneOf(StatutGroupe.class);
        };
    }

    /** RG-24 : l'annulation n'est possible qu'avant l'objectif atteint. */
    public boolean annulable() {
        return this == BROUILLON || this == EN_VALIDATION || this == OUVERT;
    }

    /** Seul un groupe OUVERT accepte des participations. */
    public boolean accepteParticipations() {
        return this == OUVERT;
    }
}

