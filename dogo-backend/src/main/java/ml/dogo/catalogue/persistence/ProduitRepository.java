package ml.dogo.catalogue.persistence;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProduitRepository extends JpaRepository<Produit, Long> {

    List<Produit> findByGrossisteIdOrderByIdDesc(Long grossisteId);

    Optional<Produit> findByIdAndGrossisteId(Long id, Long grossisteId);

    @Query("select p from Produit p join p.variantes v where v.id = :varianteId")
    Optional<Produit> trouverParVariante(@Param("varianteId") Long varianteId);
}
