package ml.dogo.catalogue.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import ml.dogo.catalogue.application.CatalogueService;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/catalogue")
public class CatalogueController {

    public record VarianteRequete(@NotBlank String sku, String taille, String couleur, @Min(0) int qteDisponible) {
    }

    public record ProduitRequete(@NotNull Long categorieId, @NotBlank String nom, String description,
                                 String paysOrigine, @NotEmpty @Valid List<VarianteRequete> variantes) {
    }

    public record ModificationRequete(String nom, String description, String paysOrigine) {
    }

    public record StockRequete(@Min(0) int qteDisponible) {
    }

    private final CatalogueService catalogue;

    public CatalogueController(CatalogueService catalogue) {
        this.catalogue = catalogue;
    }

    @GetMapping("/categories")
    public List<CatalogueService.CategorieVue> categories() {
        return catalogue.categories();
    }

    @GetMapping("/produits")
    @PreAuthorize("hasAuthority('CATALOGUE_GERER')")
    public List<CatalogueService.ProduitVue> mesProduits(@AuthenticationPrincipal UtilisateurCourant moi) {
        return catalogue.mesProduits(moi.id());
    }

    @PostMapping("/produits")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('CATALOGUE_GERER')")
    public CatalogueService.ProduitVue creer(@AuthenticationPrincipal UtilisateurCourant moi,
                                             @Valid @RequestBody ProduitRequete r) {
        return catalogue.creer(moi.id(), new CatalogueService.ProduitDemande(r.categorieId(), r.nom(),
                r.description(), r.paysOrigine(), r.variantes().stream().map(CatalogueController::demande).toList()));
    }

    @PutMapping("/produits/{id}")
    @PreAuthorize("hasAuthority('CATALOGUE_GERER')")
    public CatalogueService.ProduitVue modifier(@AuthenticationPrincipal UtilisateurCourant moi,
                                                @PathVariable long id, @RequestBody ModificationRequete r) {
        return catalogue.modifier(moi.id(), id, r.nom(), r.description(), r.paysOrigine());
    }

    @PostMapping("/produits/{id}/variantes")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('CATALOGUE_GERER')")
    public CatalogueService.ProduitVue ajouterVariante(@AuthenticationPrincipal UtilisateurCourant moi,
                                                       @PathVariable long id, @Valid @RequestBody VarianteRequete r) {
        return catalogue.ajouterVariante(moi.id(), id, demande(r));
    }

    @PatchMapping("/variantes/{id}/stock")
    @PreAuthorize("hasAuthority('CATALOGUE_GERER')")
    public CatalogueService.VarianteVue definirStock(@AuthenticationPrincipal UtilisateurCourant moi,
                                                     @PathVariable long id, @Valid @RequestBody StockRequete r) {
        return catalogue.definirStock(moi.id(), id, r.qteDisponible());
    }

    private static CatalogueService.VarianteDemande demande(VarianteRequete v) {
        return new CatalogueService.VarianteDemande(v.sku(), v.taille(), v.couleur(), v.qteDisponible());
    }
}
