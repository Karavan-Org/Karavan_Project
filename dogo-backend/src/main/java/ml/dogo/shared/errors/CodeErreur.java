package ml.dogo.shared.errors;

/** Codes d'erreur métier, chacun rattaché à un statut HTTP et, quand c'est utile, à une règle de gestion. */
public enum CodeErreur {
    NON_TROUVE(404),
    COMPTE_INEXISTANT(404),
    ACCES_REFUSE(403),
    NON_AUTHENTIFIE(401),
    DONNEES_INVALIDES(400),
    TRANSITION_INTERDITE(409),
    CONFLIT(409),
    QUOTA_INSUFFISANT(409),
    OTP_INVALIDE(400),
    COMPTE_VERROUILLE(423),
    COMPTE_INACTIF(403),
    PAIEMENT_INVALIDE(409),
    CODE_RETRAIT_INVALIDE(400),
    CODE_RETRAIT_BLOQUE(423),
    REMBOURSEMENT_INVALIDE(409);

    private final int statutHttp;

    CodeErreur(int statutHttp) {
        this.statutHttp = statutHttp;
    }

    public int statutHttp() {
        return statutHttp;
    }
}
