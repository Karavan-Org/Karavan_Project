package ml.dogo.logistique.domain;

import java.util.EnumSet;
import java.util.Set;
import ml.dogo.shared.domain.MachineEtats;

/** Cycle de vie d'une commande (RG-44 à RG-56). */
public enum StatutCommande implements MachineEtats<StatutCommande> {
    CREEE, PREPAREE, EXPEDIEE, ARRIVEE, EN_ATTENTE_RETRAIT, COLLECTEE, ANNULEE;

    @Override
    public Set<StatutCommande> suivants() {
        return switch (this) {
            case CREEE -> EnumSet.of(PREPAREE, ANNULEE);
            case PREPAREE -> EnumSet.of(EXPEDIEE, ANNULEE);
            case EXPEDIEE -> EnumSet.of(ARRIVEE);
            case ARRIVEE -> EnumSet.of(EN_ATTENTE_RETRAIT);
            case EN_ATTENTE_RETRAIT -> EnumSet.of(COLLECTEE);
            case COLLECTEE, ANNULEE -> EnumSet.noneOf(StatutCommande.class);
        };
    }

    /** RG-51 : le Grossiste ne modifie une commande qu'avant son expédition. */
    public boolean modifiableParGrossiste() {
        return this == CREEE || this == PREPAREE;
    }
}
