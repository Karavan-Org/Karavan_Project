package ml.dogo.identite.persistence;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CompteExterneRepository extends JpaRepository<CompteExterne, Long> {

    @Query("SELECT ce FROM CompteExterne ce JOIN FETCH ce.utilisateur WHERE ce.fournisseur = :fournisseur AND ce.sub = :sub")
    Optional<CompteExterne> findByFournisseurAndSubAvecUtilisateur(@Param("fournisseur") String fournisseur, @Param("sub") String sub);

    Optional<CompteExterne> findByFournisseurAndSub(String fournisseur, String sub);

    List<CompteExterne> findByUtilisateurId(Long utilisateurId);

    boolean existsByFournisseurAndSub(String fournisseur, String sub);

    boolean existsByUtilisateurIdAndFournisseur(Long utilisateurId, String fournisseur);
}

