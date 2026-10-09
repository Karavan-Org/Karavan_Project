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

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.multipart.MultipartFile;
import ml.dogo.catalogue.application.StockageService;

@RestController
@RequestMapping("/api/catalogue")
public class CatalogueController {

    public record VarianteRequete(@NotBlank String sku, String taille, String couleur, @Min(0) int qteDisponible) {
    }

    public record ProduitRequete(@NotNull Long categorieId, @NotBlank String nom, String description,
                                 String paysOrigine, String photoUrl, @NotEmpty @Valid List<VarianteRequete> variantes,
                                 java.math.BigDecimal prixGros) {
    }

    public record ModificationRequete(String nom, String description, String paysOrigine) {
    }

    public record StockRequete(@Min(0) int qteDisponible) {
    }

    public record UploadPhotoReponse(String photoUrl) {
    }

    private final CatalogueService catalogue;
    private final StockageService stockage;

    public CatalogueController(CatalogueService catalogue, StockageService stockage) {
        this.catalogue = catalogue;
        this.stockage = stockage;
    }

    @PostMapping(value = "/upload-photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('CATALOGUE_GERER')")
    public UploadPhotoReponse uploaderPhoto(@AuthenticationPrincipal UtilisateurCourant moi,
                                           @RequestParam("photo") MultipartFile photo) {
        String url = stockage.stockerPhotoProduit(photo, moi.id());
        return new UploadPhotoReponse(url);
    }

    @GetMapping("/categories")
    public List<CatalogueService.CategorieVue> categories() {
        return catalogue.categories();
    }

    @GetMapping("/produits-disponibles")
    // Réservé aux courtiers : un grossiste crée ses groupes sur son propre catalogue, il ne voit pas celui des autres.
    @PreAuthorize("hasAuthority('GROUPE_CREER') and hasAuthority('CAMPAGNE_EXPLORER')")
    public List<CatalogueService.ProduitDisponibleVue> produitsDisponibles() {
        return catalogue.produitsDisponibles();
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
                r.description(), r.paysOrigine(), r.photoUrl(), r.variantes().stream().map(CatalogueController::demande).toList(),
                r.prixGros()));
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
