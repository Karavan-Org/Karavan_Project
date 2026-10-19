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

    /** V17 insère l'administrateur Logistique : seul un administrateur TECHNIQUE prouve que l'amorçage a eu lieu. */
    @Query("select count(a) from Administrateur a where a.roleAdministratif = ml.dogo.identite.domain.RoleAdministratif.TECHNIQUE")
    long nombreAdministrateursTechniques();

    // Les compteurs d'échecs sont incrémentés en SQL pour rester exacts même sous requêtes parallèles (RG-07).

    @Modifying
    @Query(nativeQuery = true, value = "UPDATE utilisateur SET tentatives_echecs = tentatives_echecs + 1 WHERE id = :id")
    int incrementerEchecsPin(@Param("id") long id);

    @Query(nativeQuery = true, value = "SELECT tentatives_echecs FROM utilisateur WHERE id = :id")
    int tentativesPin(@Param("id") long id);

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from Utilisateur u where u.telephone = :telephone")
    Optional<Utilisateur> findByTelephoneForUpdate(@Param("telephone") String telephone);

    @Modifying
    @Query(nativeQuery = true, value = "UPDATE utilisateur SET verrouille_jusqua = :jusqua WHERE id = :id")
    int verrouiller(@Param("id") long id, @Param("jusqua") Instant jusqua);

    @Query("select c from Commercant c order by c.id desc")
    List<Commercant> tousLesCommercants();

    @Query("select g from Grossiste g order by g.id desc")
    List<Grossiste> tousLesGrossistes();

    @Query("select c from Courtier c order by c.id desc")
    List<Courtier> tousLesCourtiers();

    @Query("select a from Administrateur a order by a.id")
    List<Administrateur> tousLesAdministrateurs();

    @Query("select count(c) from Commercant c")
    long nombreCommercants();

    @Query("select count(g) from Grossiste g")
    long nombreGrossistes();

    @Query("select count(c) from Courtier c")
    long nombreCourtiers();
}
