package ml.dogo.shared.domain;

import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

/**
 * Contrat commun des statuts : chaque énumération de statut déclare ses transitions autorisées.
 * Toute modification d'un statut passe par {@link #verifierTransition}, jamais par une affectation directe.
 */
public interface MachineEtats<E extends Enum<E> & MachineEtats<E>> {

    /** Statuts atteignables depuis ce statut (vide pour un statut terminal). */
    java.util.Set<E> suivants();

    default boolean peutAllerVers(E cible) {
        return suivants().contains(cible);
    }

    default boolean estTerminal() {
        return suivants().isEmpty();
    }

    @SuppressWarnings("unchecked")
    default E verifierTransition(E cible, String regle) {
        if (!peutAllerVers(cible)) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, regle,
                    "Transition interdite : " + this + " -> " + cible);
        }
        return cible;
    }
}
