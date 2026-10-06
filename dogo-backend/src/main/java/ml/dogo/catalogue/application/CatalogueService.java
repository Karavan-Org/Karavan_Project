package ml.dogo.catalogue.application;

import java.util.ArrayList;
import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.catalogue.api.EngagementProduit;
import ml.dogo.catalogue.persistence.Categorie;
import ml.dogo.catalogue.persistence.CategorieRepository;
import ml.dogo.catalogue.persistence.Produit;
import ml.dogo.catalogue.persistence.ProduitRepository;
import ml.dogo.catalogue.persistence.VarianteProduit;
import ml.dogo.catalogue.persistence.VarianteProduitRepository;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Catalogue d'un Grossiste : produits, variantes, stock (RG-11 à RG-15). */
@Service
public class CatalogueService {

    public record VarianteDemande(String sku, String taille, String couleur, int qteDisponible) {
    }

    public record ProduitDemande(Long categorieId, String nom, String description, String paysOrigine,
                                 String photoUrl, List<VarianteDemande> variantes) {
    }

    public record VarianteVue(long id, String sku, String taille, String couleur, int qteDisponible) {
    }

    public record ProduitVue(long id, long categorieId, String nom, String description, String photoUrl, String paysOrigine,
                             List<VarianteVue> variantes) {
    }

    public record CategorieVue(long id, String nom, String description) {
    }

    private final ProduitRepository produits;
    private final VarianteProduitRepository variantes;
    private final CategorieRepository categories;
    private final IdentiteApi identite;
    private final EngagementProduit engagement;
    private final AuditApi audit;

    public CatalogueService(ProduitRepository produits, VarianteProduitRepository variantes,
                            CategorieRepository categories, IdentiteApi identite, EngagementProduit engagement,
                            AuditApi audit) {
        this.produits = produits;
        this.variantes = variantes;
        this.categories = categories;
        this.identite = identite;
        this.engagement = engagement;
        this.audit = audit;
    }

    @Transactional(readOnly = true)
    public List<CategorieVue> categories() {
        return categories.findByActiveTrueOrderByNomAsc().stream()
                .map(c -> new CategorieVue(c.getId(), c.getNom(), c.getDescription())).toList();
    }

    /** RG-11, RG-12, RG-14. */
    @Transactional
    public ProduitVue creer(long grossisteId, ProduitDemande d) {
        exigerGrossisteActif(grossisteId);
        if (d.categorieId() == null || d.nom() == null || d.nom().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-11", "Catégorie et nom sont obligatoires");
        }
        Categorie categorie = categories.findById(d.categorieId())
                .orElseThrow(() -> ErreurMetier.nonTrouve("Catégorie", d.categorieId()));
        if (!categorie.isActive()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-14", "Cette catégorie n'accepte plus de nouveaux produits");
        }
        if (d.variantes() == null || d.variantes().isEmpty()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-12", "Un produit a au moins une variante");
        }
        List<VarianteProduit> creees = new ArrayList<>();
        for (VarianteDemande v : d.variantes()) {
            creees.add(nouvelleVariante(v, creees));
        }
        Produit p = produits.save(new Produit(grossisteId, categorie.getId(), d.nom().strip(), d.description(),
                d.photoUrl(), d.paysOrigine(), creees));
        audit.tracer(grossisteId, "PRODUIT_CREE", null, "produit=" + p.getId());
        return vue(p);
    }

    @Transactional(readOnly = true)
    public List<ProduitVue> mesProduits(long grossisteId) {
        return produits.findByGrossisteIdOrderByIdDesc(grossisteId).stream().map(CatalogueService::vue).toList();
    }

    /** RG-15 : plus de modification d'un produit engagé dans un groupe OUVERT. */
    @Transactional
    public ProduitVue modifier(long grossisteId, long produitId, String nom, String description, String pays) {
        Produit p = produitDuGrossiste(grossisteId, produitId);
        exigerNonEngage(produitId);
        p.modifier(nom, description, pays);
        return vue(p);
    }

    /** RG-12, RG-15. */
    @Transactional
    public ProduitVue ajouterVariante(long grossisteId, long produitId, VarianteDemande d) {
        Produit p = produitDuGrossiste(grossisteId, produitId);
        exigerNonEngage(produitId);
        p.ajouterVariante(nouvelleVariante(d, p.getVariantes()));
        produits.flush();
        return vue(p);
    }

    /** RG-13 : le stock peut évoluer à tout moment, mais jamais devenir négatif. */
    @Transactional
    public VarianteVue definirStock(long grossisteId, long varianteId, int quantite) {
        Produit p = produits.trouverParVariante(varianteId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Variante", varianteId));
        if (!p.getGrossisteId().equals(grossisteId)) {
            throw ErreurMetier.nonTrouve("Variante", varianteId);
        }
        VarianteProduit v = p.getVariantes().stream().filter(x -> x.getId().equals(varianteId)).findFirst()
                .orElseThrow();
        v.definirStock(quantite);
        return vue(v);
    }

    // ---------------------------------------------------------------- utilitaires

    private void exigerGrossisteActif(long grossisteId) {
        IdentiteApi.ActeurInfo a = identite.exigerActif(grossisteId);
        if (!"GROSSISTE".equals(a.type())) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-11", "Réservé aux grossistes validés");
        }
    }

    private Produit produitDuGrossiste(long grossisteId, long produitId) {
        return produits.findByIdAndGrossisteId(produitId, grossisteId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Produit", produitId));
    }

    private void exigerNonEngage(long produitId) {
        if (engagement.engageDansGroupeOuvert(produitId)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-15",
                    "Ce produit est engagé dans une campagne ouverte : modification impossible");
        }
    }

    private VarianteProduit nouvelleVariante(VarianteDemande d, List<VarianteProduit> dejaLa) {
        if (d.sku() == null || d.sku().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-12", "Le SKU est obligatoire");
        }
        String sku = d.sku().strip().toUpperCase(java.util.Locale.ROOT);
        boolean doublon = variantes.existsBySku(sku) || dejaLa.stream().anyMatch(v -> v.getSku().equals(sku));
        if (doublon) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-12", "SKU déjà utilisé : " + sku);
        }
        return new VarianteProduit(sku, d.taille(), d.couleur(), d.qteDisponible());
    }

    private static ProduitVue vue(Produit p) {
        return new ProduitVue(p.getId(), p.getCategorieId(), p.getNom(), p.getDescription(), p.getPhotoUrl(), p.getPaysOrigine(),
                p.getVariantes().stream().map(CatalogueService::vue).toList());
    }

    private static VarianteVue vue(VarianteProduit v) {
        return new VarianteVue(v.getId(), v.getSku(), v.getTaille(), v.getCouleur(), v.getQteDisponible());
    }
}
