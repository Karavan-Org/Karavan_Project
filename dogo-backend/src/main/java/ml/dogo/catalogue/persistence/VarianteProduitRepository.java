package ml.dogo.catalogue.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

public interface VarianteProduitRepository extends JpaRepository<VarianteProduit, Long> {

    boolean existsBySku(String sku);
}
