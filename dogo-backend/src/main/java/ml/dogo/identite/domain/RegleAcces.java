package ml.dogo.identite.domain;

import java.time.Duration;
import java.time.Instant;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

/** Règles d'accès pures : OTP (RG-02) et verrouillage du PIN (RG-07). */
public final class RegleAcces {

    private RegleAcces() {
    }

    /** RG-02 : un OTP est valable s'il n'est ni expiré, ni utilisé, ni épuisé en tentatives. */
    public static void verifierOtpUtilisable(boolean utilise, Instant expiration, int tentatives, int maxTentatives,
                                             Instant maintenant) {
        if (utilise || !maintenant.isBefore(expiration) || tentatives >= maxTentatives) {
            throw new ErreurMetier(CodeErreur.OTP_INVALIDE, "RG-02", "Code invalide ou expiré");
        }
    }

    /** RG-07 : verrouillage progressif après {@code max} échecs consécutifs. */
    public static Instant verrouillageApres(int echecs, int max, Duration dureeBase, Instant maintenant) {
        if (echecs < max) {
            return null;
        }
        long multiplicateur = switch (echecs - max) {
            case 0 -> 1;
            case 1 -> 4;
            case 2 -> 16;
            default -> 96;
        };
        return maintenant.plus(dureeBase.multipliedBy(multiplicateur));
    }

    public static void verifierNonVerrouille(Instant verrouilleJusqua, Instant maintenant) {
        if (verrouilleJusqua != null && maintenant.isBefore(verrouilleJusqua)) {
            throw new ErreurMetier(CodeErreur.COMPTE_VERROUILLE, "RG-07",
                    "Compte temporairement verrouillé, réessayez plus tard");
        }
    }

    /** Le PIN compte exactement 4 chiffres, pas tous identiques (RG-07). */
    public static void verifierFormatPin(String pin) {
        if (pin == null || !pin.matches("\\d{4}") || pin.chars().distinct().count() == 1) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-07",
                    "Le code PIN doit comporter exactement 4 chiffres (non tous identiques)");
        }
    }
}
