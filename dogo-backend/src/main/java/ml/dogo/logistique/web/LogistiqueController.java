package ml.dogo.logistique.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import ml.dogo.logistique.application.CommandeService;
import ml.dogo.logistique.application.LocalisationService;
import ml.dogo.logistique.application.PointRetraitService;
import ml.dogo.logistique.application.RetraitService;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Points de retrait, commandes, acheminement et retrait (RG-44 à RG-56). */
@RestController
@RequestMapping("/api")
public class LogistiqueController {

    public record PointRequete(@NotBlank String nom, @NotBlank String adresse, String quartier, String lienGoogleMap) {
    }

    public record ArriveeRequete(@NotNull Long pointRetraitId) {
    }

    /** Soit {@code qrToken} (scan), soit {@code commandeId} + {@code pin}. */
    public record RetraitRequete(Long commandeId, String qrToken, String pin) {
    }

    private final PointRetraitService points;
    private final CommandeService commandes;
    private final RetraitService retraits;
    private final LocalisationService localisation;

    public LogistiqueController(PointRetraitService points, CommandeService commandes, RetraitService retraits,
                                LocalisationService localisation) {
        this.points = points;
        this.commandes = commandes;
        this.retraits = retraits;
        this.localisation = localisation;
    }

    // ---- points de retrait

    @GetMapping("/points-retrait")
    public List<PointRetraitService.PointVue> lesPoints() {
        return points.lister();
    }

    @PostMapping("/admin/points-retrait")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('POINT_RETRAIT_GERER')")
    public PointRetraitService.PointVue creerPoint(@AuthenticationPrincipal UtilisateurCourant moi,
                                                   @Valid @RequestBody PointRequete r) {
        return points.creer(moi.id(), r.nom(), r.adresse(), r.quartier(), r.lienGoogleMap());
    }

    @PutMapping("/admin/points-retrait/{id}")
    @PreAuthorize("hasAuthority('POINT_RETRAIT_GERER')")
    public PointRetraitService.PointVue modifierPoint(@AuthenticationPrincipal UtilisateurCourant moi,
                                                      @PathVariable long id,
                                                      @Valid @RequestBody PointRequete r) {
        return points.modifier(moi.id(), id, r.nom(), r.adresse(), r.quartier(), r.lienGoogleMap());
    }

    /** Coordonnées d'un dépôt (lien Google Maps ou adresse) pour l'itinéraire affiché dans l'application. */
    @GetMapping("/localisation")
    public LocalisationService.Coordonnees localiser(@RequestParam(required = false) String lien,
                                                     @RequestParam(required = false) String adresse) {
        return localisation.localiser(lien, adresse);
    }

    // ---- consultation

    @GetMapping("/moi/commandes")
    @PreAuthorize("hasAuthority('COMMANDE_LIRE')")
    public List<CommandeService.CommandeVue> mesCommandes(@AuthenticationPrincipal UtilisateurCourant moi) {
        return commandes.mesCommandes(moi.id());
    }

    @GetMapping("/commandes/{id}")
    @PreAuthorize("hasAuthority('COMMANDE_LIRE')")
    public CommandeService.CommandeVue detail(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id) {
        return commandes.detail(moi, id);
    }

    @GetMapping("/groupes/{groupeId}/commandes")
    @PreAuthorize("hasAuthority('COMMANDE_LIRE')")
    public List<CommandeService.CommandeVue> duGroupe(@AuthenticationPrincipal UtilisateurCourant moi,
                                                      @PathVariable long groupeId) {
        return commandes.duGroupe(moi, groupeId);
    }

    // ---- acheminement

    @PostMapping("/groupes/{groupeId}/preparation")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public List<CommandeService.CommandeVue> preparer(@AuthenticationPrincipal UtilisateurCourant moi,
                                                      @PathVariable long groupeId) {
        return commandes.preparer(moi, groupeId);
    }

    @PostMapping("/groupes/{groupeId}/expedition")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public List<CommandeService.CommandeVue> expedier(@AuthenticationPrincipal UtilisateurCourant moi,
                                                      @PathVariable long groupeId) {
        return commandes.expedier(moi, groupeId);
    }

    @PostMapping("/admin/groupes/{groupeId}/reception")
    @PreAuthorize("hasAuthority('RECEPTION_VALIDER')")
    public List<CommandeService.CommandeVue> validerReception(@AuthenticationPrincipal UtilisateurCourant moi,
                                                              @PathVariable long groupeId) {
        return commandes.validerReception(moi, groupeId);
    }

    @PostMapping("/groupes/{groupeId}/reception-point-retrait")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public List<CommandeService.CommandeVue> arriveeAuPoint(@AuthenticationPrincipal UtilisateurCourant moi,
                                                            @PathVariable long groupeId,
                                                            @Valid @RequestBody ArriveeRequete r) {
        return commandes.confirmerArriveeAuPoint(moi, groupeId, r.pointRetraitId());
    }

    @PostMapping("/admin/groupes/{groupeId}/notifier-depot")
    @PreAuthorize("hasAuthority('RECEPTION_VALIDER')")
    public List<CommandeService.CommandeVue> notifierArriveeDepot(@AuthenticationPrincipal UtilisateurCourant moi,
                                                                 @PathVariable long groupeId,
                                                                 @Valid @RequestBody ArriveeRequete r) {
        return commandes.notifierArriveeDepot(moi, groupeId, r.pointRetraitId());
    }

    // ---- retrait

    /** Le Commerçant affiche ce jeton en QR code ; le PIN lui a été envoyé par SMS et n'est jamais relisible. */
    @GetMapping("/commandes/{id}/code-retrait")
    @PreAuthorize("hasAuthority('RETRAIT_EFFECTUER')")
    public RetraitService.CodeVue codeRetrait(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id) {
        return retraits.codeRetrait(moi.id(), id);
    }

    @PostMapping("/commandes/{id}/code-retrait/regeneration")
    @PreAuthorize("hasAuthority('RETRAIT_VALIDER')")
    public RetraitService.CodeVue regenerer(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id) {
        return retraits.regenerer(moi, id);
    }

    @PostMapping("/retraits/valider")
    @PreAuthorize("hasAuthority('RETRAIT_VALIDER')")
    public RetraitService.RetraitVue valider(@AuthenticationPrincipal UtilisateurCourant moi,
                                             @RequestBody RetraitRequete r) {
        return retraits.valider(moi, r.commandeId(), r.qrToken(), r.pin());
    }
}
