package ml.dogo.logistique.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import ml.dogo.logistique.application.ConvoiService;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
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
    public List<ConvoiService.ConvoiVue> lister() {
        return convois.lister();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('COMMANDE_LIRE', 'COMMANDE_AVANCER', 'RECEPTION_VALIDER', 'GROUPE_SUIVRE')")
    public ConvoiService.ConvoiVue detail(@PathVariable long id) {
        return convois.detail(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'GROUPE_CREER')")
    public ConvoiService.ConvoiVue creer(@Valid @RequestBody ConvoiService.CreationDemande r) {
        return convois.creer(r);
    }

    @PostMapping("/{id}/evenements")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue ajouterEtape(@PathVariable long id,
                                               @Valid @RequestBody ConvoiService.EvenementDemande r) {
        return convois.ajouterEtape(id, r);
    }

    @PostMapping("/{id}/transit")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue lancerTransit(@PathVariable long id) {
        return convois.lancerTransit(id);
    }

    @PostMapping("/{id}/douane")
    @PreAuthorize("hasAnyAuthority('COMMANDE_AVANCER', 'RECEPTION_VALIDER')")
    public ConvoiService.ConvoiVue declarerDouane(@PathVariable long id,
                                                 @RequestBody(required = false) LocalisationRequete r) {
        return convois.declarerDouane(id, r != null ? r.localisation() : null);
    }
}
