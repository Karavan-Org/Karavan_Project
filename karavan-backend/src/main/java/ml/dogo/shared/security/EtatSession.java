package ml.dogo.shared.security;

/** Résultat de la vérification d'une session (RG-03, RG-08, RG-09). */
public enum EtatSession {
    /** Session invalide, expirée, ou compte suspendu / désactivé : la requête reste anonyme. */
    INVALIDE,
    /** Compte actif : accès selon les permissions. */
    ACTIF,
    /**
     * Compte en attente de validation (Grossiste ou Courtier dont le dossier KYC n'est pas encore approuvé) :
     * seul le parcours de vérification lui est ouvert, voir {@link AccesCompteEnAttente}.
     */
    EN_ATTENTE,
    /**
     * Compte actif dont le mot de passe a été fixé par un tiers (administrateur principal, administrateur créé depuis la
     * console) : seul le changement de mot de passe lui est ouvert, voir {@link AccesMotDePasseProvisoire} (RG-07b).
     */
    MOT_DE_PASSE_PROVISOIRE
}
