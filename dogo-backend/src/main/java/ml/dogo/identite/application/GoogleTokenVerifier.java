package ml.dogo.identite.application;

/** Service de vérification cryptographique et d'extraction des jetons Google ID Token. */
public interface GoogleTokenVerifier {

    /**
     * Valide la signature, l'audience, l'émetteur et l'expiration du jeton d'identité Google.
     * Les clés publiques Google sont automatiquement mises en cache avec respect des en-têtes HTTP.
     *
     * @param idToken le jeton d'identité brut transmis par le client
     * @return les claims vérifiés (sub, email, email_verified, name, picture)
     * @throws ml.dogo.shared.errors.ErreurMetier si le jeton est invalide, expiré ou corrompu
     */
    GoogleIdTokenInfo verifier(String idToken);
}

