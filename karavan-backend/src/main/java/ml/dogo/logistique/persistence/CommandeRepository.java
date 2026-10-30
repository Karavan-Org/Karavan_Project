package ml.dogo.logistique.persistence;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import ml.dogo.logistique.domain.StatutCommande;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommandeRepository extends JpaRepository<Commande, Long> {

    List<Commande> findByCommercantIdOrderByIdDesc(Long commercantId);

    List<Commande> findByGroupeIdOrderByIdAsc(Long groupeId);

    boolean existsByParticipationId(Long participationId);

    long countByGroupeIdAndStatutNot(Long groupeId, StatutCommande statut);

    long countByGroupeIdAndStatutNotIn(Long groupeId, Collection<StatutCommande> statuts);

    /** Groupe d'une commande, sans charger l'entité : sert à verrouiller ensuite toutes les commandes du groupe. */
    @Query(nativeQuery = true, value = "SELECT groupe_id FROM commande WHERE id = :id")
    java.util.Optional<Long> groupeDe(@Param("id") Long id);

    /** Verrou d'écriture sur toutes les commandes d'un groupe : deux opérateurs ne les font pas avancer en même temps. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Commande c where c.groupeId = :groupeId order by c.id")
    List<Commande> verrouillerDuGroupe(@Param("groupeId") Long groupeId);
}
