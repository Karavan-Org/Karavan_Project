package ml.dogo.logistique.domain;

import java.time.Instant;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

/** Règles du code de retrait (RG-53 à RG-56). */
public final class RegleRetrait {

    private RegleRetrait() {
    }

    /**
     * Vérifie qu'un code peut être présenté. Les exceptions distinguent « bloqué » (423) et « invalide » (400),
     * sans dire si c'est le PIN ou le QR qui est faux.
     */
    public static void verifierUtilisable(boolean utilise, boolean bloque, Instant expiration, Instant maintenant) {
        if (bloque) {
            throw new ErreurMetier(CodeErreur.CODE_RETRAIT_BLOQUE, "RG-54",
                    "Code bloqué après trop de tentatives : contactez le support");
        }
        if (utilise) {
            throw new ErreurMetier(CodeErreur.CODE_RETRAIT_INVALIDE, "RG-54", "Ce code a déjà été utilisé");
        }
        if (!maintenant.isBefore(expiration)) {
            throw new ErreurMetier(CodeErreur.CODE_RETRAIT_INVALIDE, "RG-54", "Ce code a expiré");
        }
    }

    /** Vrai si le nombre d'échecs atteint le maximum autorisé : le code doit être bloqué. */
    public static boolean doitBloquer(int tentativesEchouees, int maxTentatives) {
        return tentativesEchouees >= maxTentatives;
    }
}
