package ml.dogo.groupeachat.web;

import java.util.List;
import ml.dogo.groupeachat.application.PaysService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Exposition des pays partenaires d'importation Karavan pour les listes de sélection
 * (grossiste et courtier à la création de groupe, filtres).
 */
@RestController
@RequestMapping("/api/pays")
public class PaysController {

    private final PaysService paysService;

    public PaysController(PaysService paysService) {
        this.paysService = paysService;
    }

    @GetMapping
    public List<PaysService.PaysVue> lister() {
        return paysService.listerActifs();
    }
}
