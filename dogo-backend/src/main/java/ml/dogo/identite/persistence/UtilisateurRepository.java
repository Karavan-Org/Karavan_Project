package ml.dogo.identite.persistence;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import ml.dogo.identite.domain.StatutCompte;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UtilisateurRepository extends JpaRepository<Utilisateur, Long> {

    Optional<Utilisateur> findByTelephone(String telephone);

    boolean existsByTelephone(String telephone);

    @Query("select u.statutCompte from Utilisateur u where u.id = :id")
    Optional<StatutCompte> statutDe(@Param("id") Long id);

    @Query("select a.id from Administrateur a where a.statutCompte = ml.dogo.identite.domain.StatutCompte.ACTIF order by a.id")
    List<Long> identifiantsAdministrateursActifs();

    @Query("select count(a) from Administrateur a")
    long nombreAdministrateurs();

    // Les compteurs d'échecs sont incrémentés en SQL pour rester exacts même sous requêtes parallèles (RG-07).

    @Modifying
    @Query(nativeQuery = true, value = "UPDATE utilisateur SET tentatives_pin = tentatives_pin + 1 WHERE id = :id")
    int incrementerEchecsPin(@Param("id") long id);

    @Query(nativeQuery = true, value = "SELECT tentatives_pin FROM utilisateur WHERE id = :id")
    int tentativesPin(@Param("id") long id);

    @Modifying
    @Query(nativeQuery = true, value = "UPDATE utilisateur SET verrouille_jusqua = :jusqua, tentatives_pin = 0 WHERE id = :id")
    int verrouiller(@Param("id") long id, @Param("jusqua") Instant jusqua);
}
