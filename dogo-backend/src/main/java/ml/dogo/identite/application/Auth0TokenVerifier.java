package ml.dogo.identite.application;

/**
 * Service de vérification et décodage cryptographique des jetons OAuth2 / OIDC Auth0 (RG-07).
 */
public interface Auth0TokenVerifier {

    /**
     * Valide la signature, l'audience, l'émetteur et l'expiration d'un ID Token ou Access Token Auth0.
     *
     * @param token Le jeton Auth0 (ID token JWT ou Access token)
     * @return Les informations d'identité validées (sub, email, nom, photo)
     */
    Auth0UserInfo verifier(String token);
}

