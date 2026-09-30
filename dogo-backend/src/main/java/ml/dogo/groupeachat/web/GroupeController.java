package ml.dogo.groupeachat.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import ml.dogo.groupeachat.application.GroupeService;
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

@RestController
@RequestMapping("/api")
public class GroupeController {

    public record GroupeRequete(
            Long produitId, @NotNull @Positive Integer quantiteCible, @NotNull Instant dateLimite,
            @NotNull BigDecimal marchandise, @NotNull BigDecimal transport, @NotNull BigDecimal douane,
            @NotNull BigDecimal autres, Integer delaiLivraisonJours, String politiqueAnnulation,
            Integer quantiteMinParCommercant) {

        GroupeService.Demande versDemande() {
            return new GroupeService.Demande(produitId, quantiteCible, dateLimite, marchandise, transport, douane,
                    autres, delaiLivraisonJours, politiqueAnnulation, quantiteMinParCommercant);
        }
    }

    public record DecisionRequete(@NotNull Boolean approuve, String commentaire) {
    }

    public record MotifRequete(@NotBlank String motif) {
    }

    private final GroupeService groupes;

    public GroupeController(GroupeService groupes) {
        this.groupes = groupes;
    }

    // ------------------------------------------------------------- consultation

    @GetMapping("/groupes")
    @PreAuthorize("hasAuthority('CAMPAGNE_EXPLORER')")
    public List<GroupeService.GroupeVue> explorer(@RequestParam(required = false) Long categorieId,
                                                  @RequestParam(required = false, name = "q") String recherche) {
        return groupes.explorer(categorieId, recherche);
    }

    @GetMapping("/groupes/mes-groupes")
    @PreAuthorize("hasAuthority('GROUPE_CREER')")
    public List<GroupeService.GroupeVue> mesGroupes(@AuthenticationPrincipal UtilisateurCourant moi) {
        return groupes.duCourtier(moi.id());
    }

    @GetMapping("/groupes/a-valider")
    @PreAuthorize("hasAuthority('GROUPE_DISPONIBILITE_VALIDER')")
    public List<GroupeService.GroupeVue> aValider(@AuthenticationPrincipal UtilisateurCourant moi) {
        return groupes.aValiderParGrossiste(moi.id());
    }

    @GetMapping("/admin/groupes/en-validation")
    @PreAuthorize("hasAuthority('GROUPE_PUBLICATION_VALIDER')")
    public List<GroupeService.GroupeVue> enValidation() {
        return groupes.enValidation();
    }

    @GetMapping("/groupes/{id}")
    @PreAuthorize("hasAnyAuthority('CAMPAGNE_EXPLORER','GROUPE_SUIVRE','GROUPE_DISPONIBILITE_VALIDER')")
    public GroupeService.GroupeVue detail(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id) {
        return groupes.detail(moi, id);
    }

    @GetMapping("/groupes/{id}/historique")
    @PreAuthorize("hasAnyAuthority('CAMPAGNE_EXPLORER','GROUPE_SUIVRE','GROUPE_DISPONIBILITE_VALIDER')")
    public List<GroupeService.TransitionVue> historique(@AuthenticationPrincipal UtilisateurCourant moi,
                                                        @PathVariable long id) {
        return groupes.historique(moi, id);
    }

    // ----------------------------------------------------------------- actions

    @PostMapping("/groupes")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('GROUPE_CREER')")
    public GroupeService.GroupeVue creer(@AuthenticationPrincipal UtilisateurCourant moi,
                                         @Valid @RequestBody GroupeRequete r) {
        return groupes.creer(moi.id(), r.versDemande());
    }

    @PutMapping("/groupes/{id}")
    @PreAuthorize("hasAuthority('GROUPE_CREER')")
    public GroupeService.GroupeVue modifier(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id,
                                            @Valid @RequestBody GroupeRequete r) {
        return groupes.modifier(moi.id(), id, r.versDemande());
    }

    @PostMapping("/groupes/{id}/soumission")
    @PreAuthorize("hasAuthority('GROUPE_CREER')")
    public GroupeService.GroupeVue soumettre(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id) {
        return groupes.soumettre(moi.id(), id);
    }

    @PostMapping("/groupes/{id}/disponibilite")
    @PreAuthorize("hasAuthority('GROUPE_DISPONIBILITE_VALIDER')")
    public GroupeService.GroupeVue validerDisponibilite(@AuthenticationPrincipal UtilisateurCourant moi,
                                                        @PathVariable long id) {
        return groupes.validerDisponibilite(moi.id(), id);
    }

    @PostMapping("/admin/groupes/{id}/publication")
    @PreAuthorize("hasAuthority('GROUPE_PUBLICATION_VALIDER')")
    public GroupeService.GroupeVue decider(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id,
                                           @Valid @RequestBody DecisionRequete r) {
        return groupes.decider(moi.id(), id, r.approuve(), r.commentaire());
    }

    @PostMapping("/groupes/{id}/annulation")
    @PreAuthorize("hasAuthority('GROUPE_ANNULER')")
    public GroupeService.GroupeVue annuler(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id,
                                           @Valid @RequestBody MotifRequete r) {
        return groupes.annuler(moi, id, r.motif());
    }
}

