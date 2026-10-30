package ml.dogo.notification.api;

/** Envoi d'une notification à un utilisateur (RG-69). Un échec d'envoi ne bloque jamais l'opération métier (RG-70). */
public interface NotificationApi {

    /** Notifie un utilisateur par SMS et garde une trace dans son historique. */
    void notifier(long utilisateurId, String contenu);

    /**
     * Envoie un SMS sans le conserver : réservé aux messages contenant un secret (code OTP, RG-71) ou adressés
     * à un numéro qui n'a pas encore de compte vérifié.
     */
    void envoyerSms(String telephone, String message);
}
