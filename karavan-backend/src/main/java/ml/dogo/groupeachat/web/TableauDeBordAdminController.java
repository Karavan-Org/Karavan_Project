package ml.dogo.groupeachat.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import ml.dogo.groupeachat.application.GroupeService;
import ml.dogo.groupeachat.application.TableauDeBordAdminService;
import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Contrôleur REST du nouveau Tableau de Bord Administrateur Karavan.
 * Réservé exclusivement au rôle Administrateur.
 */
@RestController
@RequestMapping("/api/admin/tableau-de-bord")
@PreAuthorize("hasRole('ADMINISTRATEUR') or hasAuthority('ROLE_ADMINISTRATEUR') or hasAuthority('AUDIT_LIRE')")
public class TableauDeBordAdminController {

    public record PaysAssignationRequete(
            @NotBlank(message = "Le code pays est obligatoire")
            @Size(min = 2, max = 2, message = "Le code ISO doit comporter 2 lettres")
            String paysOrigineCode
    ) {
    }

    private final TableauDeBordAdminService service;

    public TableauDeBordAdminController(TableauDeBordAdminService service) {
        this.service = service;
    }

    /**
     * Résumé pour les compteurs d'accueil, le réseau d'utilisateurs et la colonne droite de statistiques.
     */
    @GetMapping("/resume")
    public TableauDeBordAdminService.ResumeVue resume() {
        return service.resume();
    }

    /**
     * Liste des groupes filtrable pour alimenter le cadran rotatif des groupes et le globe 3D.
     */
    @GetMapping("/groupes")
    public List<TableauDeBordAdminService.GroupeCadranVue> groupes(
            @RequestParam(required = false) StatutGroupe statut,
            @RequestParam(required = false) String pays,
            @RequestParam(required = false, name = "q") String recherche,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "200") int taille
    ) {
        return service.groupesPourCadran(statut, pays, recherche, page, taille);
    }

    /**
     * Détail d'un groupe pour le panneau coulissant gauche ouvert au clic sur le cadran ou le globe.
     */
    @GetMapping("/groupes/{id}")
    public TableauDeBordAdminService.GroupeDetailVue detail(@PathVariable long id) {
        return service.detailGroupe(id);
    }

    /**
     * Affectation rapide en un clic du pays d'origine pour les groupes existants non renseignés.
     */
    @PutMapping("/groupes/{id}/pays")
    public GroupeService.GroupeVue assignerPays(
            @AuthenticationPrincipal UtilisateurCourant moi,
            @PathVariable long id,
            @Valid @RequestBody PaysAssignationRequete r
    ) {
        return service.assignerPays(moi.id(), id, r.paysOrigineCode());
    }
}

