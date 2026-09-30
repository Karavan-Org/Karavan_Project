package ml.dogo.catalogue.api;

import java.util.List;
import java.util.Optional;

/** Ce que les autres modules ont le droit de savoir sur le catalogue. */
public interface CatalogueApi {

    record VarianteInfo(long id, long produitId, String sku, String taille, String couleur) {
    }

    record ProduitInfo(long id, long grossisteId, long categorieId, String categorie, String nom, String description,
                       String paysOrigine, List<VarianteInfo> variantes) {
    }

    Optional<ProduitInfo> produit(long produitId);

    Optional<VarianteInfo> variante(long varianteId);

    /** Somme des quantités disponibles des variantes d'un produit. */
    long stockTotal(long produitId);
}
