package ml.dogo.identite.application;

/** Informations extraites et validées d'un jeton d'identité ou profil utilisateur Auth0. */
public record Auth0UserInfo(
        String sub,
        String email,
        boolean emailVerified,
        String nom,
        String photoUrl
) {
}

