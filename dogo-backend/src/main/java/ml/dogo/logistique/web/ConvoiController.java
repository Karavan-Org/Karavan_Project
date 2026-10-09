package ml.dogo.logistique.web;

import jakarta.validation.Valid;
import java.util.List;
import ml.dogo.logistique.application.ConvoiService;
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

/**
 * Endpoints REST pour le suivi et la mise à jour des convois / expéditions (RG-46, écran suivi.svg).
 */
@RestController
@RequestMapping("/api/convois")
public class ConvoiController {

    public record LocalisationRequete(String localisation) {
    }

    private final ConvoiService convois;

    public ConvoiController(ConvoiService convois) {
        this.convois = convois;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('COMMANDE_LIRE', 'COMMANDE_AVANCER', 'RECEPTION_VALIDER', 'GROUPE_SUIVRE')")
    public List<ConvoiService.ConvoiVue> lister(@AuthenticationPrincipal UtilisateurCourant moi) {
        return convois.lister(moi);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('COMMANDE_LIRE', 'COMMANDE_AVANCER', 'RECEPTION_VALIDER', 'GROUPE_SUIVRE')")
    public ConvoiService.ConvoiVue detail(@PathVariable long id,
                                         @AuthenticationPrincipal UtilisateurCourant moi) {
        return convois.detail(id, moi);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    // L'administrateur crée le suivi des groupes portés par un grossiste (acheminés par ses soins)
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'GROUPE_CREER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue creer(@Valid @RequestBody ConvoiService.CreationDemande r,
                                        @AuthenticationPrincipal UtilisateurCourant moi) {
        return convois.creer(r, moi);
    }

    @PostMapping("/{id}/evenements")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue ajouterEtape(@PathVariable long id,
                                               @Valid @RequestBody ConvoiService.EvenementDemande r,
                                               @AuthenticationPrincipal UtilisateurCourant moi) {
        return convois.ajouterEtape(id, r, moi);
    }

    @PostMapping("/{id}/transitaire")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue remettreAuTransitaire(@PathVariable long id,
                                                         @RequestBody(required = false) LocalisationRequete r,
                                                         @AuthenticationPrincipal UtilisateurCourant moi) {
        return convois.remettreAuTransitaire(id, r != null ? r.localisation() : null, moi);
    }

    @PostMapping("/{id}/transit")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue lancerTransit(@PathVariable long id,
                                                 @AuthenticationPrincipal UtilisateurCourant moi) {
        return convois.lancerTransit(id, moi);
    }

    @PostMapping("/{id}/arrivee")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue marquerArrive(@PathVariable long id,
                                                 @RequestBody(required = false) LocalisationRequete r,
                                                 @AuthenticationPrincipal UtilisateurCourant moi) {
        return convois.marquerArrive(id, r != null ? r.localisation() : null, moi);
    }

    @PostMapping("/{id}/douane")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue declarerDouane(@PathVariable long id,
                                                 @RequestBody(required = false) LocalisationRequete r,
                                                 @AuthenticationPrincipal UtilisateurCourant moi) {
        return convois.declarerDouane(id, r != null ? r.localisation() : null, moi);
    }
}
