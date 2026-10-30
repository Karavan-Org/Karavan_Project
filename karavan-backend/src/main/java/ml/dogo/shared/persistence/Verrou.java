package ml.dogo.shared.persistence;

import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import jakarta.persistence.PersistenceContext;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Verrou d'écriture avec relecture. Si l'entité était déjà en mémoire (lue plus tôt dans la même transaction), son
 * état est rafraîchi depuis la base : on ne décide jamais sur une valeur périmée pendant qu'un autre traitement
 * modifie la même ligne (paiement, séquestre, participation, commande...).
 */
@Component
public class Verrou {

    @PersistenceContext
    private EntityManager em;

    @Transactional(propagation = Propagation.MANDATORY)
    public <T> Optional<T> ecriture(Class<T> type, Object id) {
        T entite = em.find(type, id);
        if (entite == null) {
            return Optional.empty();
        }
        em.refresh(entite, LockModeType.PESSIMISTIC_WRITE);
        return Optional.of(entite);
    }
}
