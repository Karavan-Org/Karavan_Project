package ml.dogo.participation.web;

import ml.dogo.participation.application.MembresGroupeService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Membres d'un groupe vus par l'administrateur : état des comptes, participations et actions tracées. */
@RestController
@RequestMapping("/api/admin/groupes")
@PreAuthorize("hasRole('ADMINISTRATEUR')")
public class MembresGroupeAdminController {

    private final MembresGroupeService membres;

    public MembresGroupeAdminController(MembresGroupeService membres) {
        this.membres = membres;
    }

    @GetMapping("/{groupeId}/membres")
    public MembresGroupeService.MembresGroupeVue membres(@PathVariable long groupeId) {
        return membres.membres(groupeId);
    }
}
