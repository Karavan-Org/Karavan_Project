package ml.dogo.catalogue.persistence;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CategorieRepository extends JpaRepository<Categorie, Long> {

    List<Categorie> findByActiveTrueOrderByNomAsc();
}
