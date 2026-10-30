package ml.dogo.identite.application;

/** Informations extraites et validées cryptographiquement d'un jeton d'identité Google (ID Token). */
public record GoogleIdTokenInfo(
        String sub,
        String email,
        boolean emailVerified,
        String nom,
        String photoUrl
) {
}

