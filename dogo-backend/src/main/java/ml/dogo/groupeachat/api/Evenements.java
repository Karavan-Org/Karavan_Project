package ml.dogo.groupeachat.api;

/** Événements publiés par le module campagne (synchrones : les écouteurs s'exécutent dans la même transaction). */
public final class Evenements {

    private Evenements() {
    }

    /** RG-21 / RG-44 : la quantité confirmée a atteint la cible avant la date limite. */
    public record ObjectifAtteint(long groupeId) {
    }

    /** RG-22 : la date limite est passée sans atteindre la cible. */
    public record GroupeEchoue(long groupeId) {
    }

    /** RG-24 : annulation par un administrateur ou par le courtier avant l'objectif. */
    public record GroupeAnnule(long groupeId, String motif) {
    }
}

