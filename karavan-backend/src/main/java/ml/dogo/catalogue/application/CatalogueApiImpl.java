package ml.dogo.catalogue.application;

import java.util.Optional;
import ml.dogo.catalogue.api.CatalogueApi;
import ml.dogo.catalogue.persistence.Categorie;
import ml.dogo.catalogue.persistence.CategorieRepository;
import ml.dogo.catalogue.persistence.Produit;
import ml.dogo.catalogue.persistence.ProduitRepository;
import ml.dogo.catalogue.persistence.VarianteProduit;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class CatalogueApiImpl implements CatalogueApi {

    private final ProduitRepository produits;
    private final CategorieRepository categories;

    public CatalogueApiImpl(ProduitRepository produits, CategorieRepository categories) {
        this.produits = produits;
        this.categories = categories;
    }

    @Override
    public Optional<ProduitInfo> produit(long produitId) {
        return produits.findById(produitId).map(p -> new ProduitInfo(p.getId(), p.getGrossisteId(), p.getCategorieId(),
                categories.findById(p.getCategorieId()).map(Categorie::getNom).orElse(""), p.getNom(),
                p.getDescription(), p.getPaysOrigine(), p.getPhotoUrl(),
                p.getVariantes().stream().map(CatalogueApiImpl::info).toList()));
    }

    @Override
    public Optional<VarianteInfo> variante(long varianteId) {
        return produits.trouverParVariante(varianteId).flatMap(p -> p.getVariantes().stream()
                .filter(v -> v.getId().equals(varianteId)).findFirst().map(CatalogueApiImpl::info));
    }

    @Override
    public long stockTotal(long produitId) {
        return produits.findById(produitId).map(Produit::getVariantes)
                .map(l -> l.stream().mapToLong(VarianteProduit::getQteDisponible).sum()).orElse(0L);
    }

    private static VarianteInfo info(VarianteProduit v) {
        return new VarianteInfo(v.getId(), v.getProduitId(), v.getSku(), v.getTaille(), v.getCouleur());
    }
}
