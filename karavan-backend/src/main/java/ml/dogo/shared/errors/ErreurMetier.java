package ml.dogo.shared.errors;

/** Exception levée quand une règle de gestion est violée. Traduite en réponse HTTP par le gestionnaire global. */
public class ErreurMetier extends RuntimeException {

    private final CodeErreur code;
    private final String regle;

    public ErreurMetier(CodeErreur code, String regle, String message) {
        super(message);
        this.code = code;
        this.regle = regle;
    }

    public static ErreurMetier nonTrouve(String quoi, Object id) {
        return new ErreurMetier(CodeErreur.NON_TROUVE, null, quoi + " introuvable : " + id);
    }

    public CodeErreur code() {
        return code;
    }

    /** Numéro de la règle de gestion concernée (ex. « RG-23 »), ou null. */
    public String regle() {
        return regle;
    }
}
