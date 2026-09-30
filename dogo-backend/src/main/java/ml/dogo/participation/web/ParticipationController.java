package ml.dogo.participation.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.util.List;
import ml.dogo.participation.application.ParticipationService;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ParticipationController {

    public record RejoindreRequete(@NotNull Long varianteId, @NotNull @Positive Integer quantite) {
    }

    private final ParticipationService participations;

    public ParticipationController(ParticipationService participations) {
        this.participations = participations;
    }

    @PostMapping("/groupes/{groupeId}/participations")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('PARTICIPATION_GERER')")
    public ParticipationService.ParticipationVue rejoindre(@AuthenticationPrincipal UtilisateurCourant moi,
                                                           @PathVariable long groupeId,
                                                           @Valid @RequestBody RejoindreRequete r) {
        return participations.rejoindre(moi.id(), groupeId, r.varianteId(), r.quantite());
    }

    @GetMapping("/moi/participations")
    @PreAuthorize("hasAuthority('PARTICIPATION_GERER')")
    public List<ParticipationService.ParticipationVue> mesParticipations(@AuthenticationPrincipal UtilisateurCourant moi) {
        return participations.mesParticipations(moi.id());
    }

    @GetMapping("/participations/{id}")
    @PreAuthorize("hasAuthority('PARTICIPATION_GERER')")
    public ParticipationService.ParticipationVue detail(@AuthenticationPrincipal UtilisateurCourant moi,
                                                        @PathVariable long id) {
        return participations.detail(moi.id(), id);
    }

    @GetMapping("/participations/{id}/historique")
    @PreAuthorize("hasAuthority('PARTICIPATION_GERER')")
    public List<ParticipationService.EtapeVue> historique(@AuthenticationPrincipal UtilisateurCourant moi,
                                                          @PathVariable long id) {
        return participations.historique(moi.id(), id);
    }

    @PostMapping("/participations/{id}/annulation")
    @PreAuthorize("hasAuthority('PARTICIPATION_GERER')")
    public ParticipationService.ParticipationVue annuler(@AuthenticationPrincipal UtilisateurCourant moi,
                                                         @PathVariable long id) {
        return participations.annuler(moi.id(), id);
    }
}
