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

    /**
     * Règle de sécurité mot de passe : entre 8 et 64 caractères, au moins 1 majuscule, 1 minuscule et 1 chiffre.
     */
    public static void verifierFormatMotDePasse(String motDePasse) {
        if (motDePasse == null || motDePasse.length() < 8 || motDePasse.length() > 64
                || motDePasse.chars().noneMatch(Character::isUpperCase)
                || motDePasse.chars().noneMatch(Character::isLowerCase)
                || motDePasse.chars().noneMatch(Character::isDigit)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-07",
                    "Le mot de passe doit comporter entre 8 et 64 caractères, avec au moins une majuscule, une minuscule et un chiffre");
        }
    }

    /** Rétrocompatibilité transitoire. */
    public static void verifierFormatPin(String pin) {
        if (pin != null && pin.length() >= 8) {
            verifierFormatMotDePasse(pin);
            return;
        }
        if (pin == null || !pin.matches("\\d{4}") || pin.chars().distinct().count() == 1) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-07",
                    "Le mot de passe doit comporter entre 8 et 64 caractères, avec au moins une majuscule, une minuscule et un chiffre");
        }
    }
}
