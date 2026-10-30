package ml.dogo.notification.api;

import java.util.Optional;

/**
 * Port sortant du module notification : « à quel numéro écrire à cet utilisateur ? ». Il est implémenté par le module
 * identite, qui possède les numéros ; ainsi notification ne dépend d'aucun autre module (RG-69).
 */
public interface AnnuaireTelephones {

    Optional<String> telephoneDe(long utilisateurId);
}
