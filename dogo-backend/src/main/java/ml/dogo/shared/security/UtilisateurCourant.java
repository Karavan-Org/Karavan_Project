package ml.dogo.shared.security;

import java.util.Collection;

/** Utilisateur authentifié de la requête en cours (extrait du jeton JWT). */
public record UtilisateurCourant(long id, String type, Collection<String> permissions, long sessionId) {

    public boolean aPermission(String code) {
        return permissions.contains(code);
    }

    public boolean estAdministrateur() {
        return "ADMINISTRATEUR".equals(type);
    }
}
