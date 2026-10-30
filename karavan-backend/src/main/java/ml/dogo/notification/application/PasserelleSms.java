package ml.dogo.notification.application;

/** Port d'envoi de SMS. La version de démonstration écrit dans les logs ; un vrai fournisseur la remplacera. */
public interface PasserelleSms {

    /** @return vrai si le SMS a été accepté par le fournisseur. */
    boolean envoyer(String telephone, String message);
}
