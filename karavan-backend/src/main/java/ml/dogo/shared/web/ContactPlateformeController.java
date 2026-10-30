package ml.dogo.shared.web;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Coordonnées du support de la plateforme, lues dans la configuration (variables d'environnement
 * DOGO_SUPPORT_*) : une seule source pour toutes les applications, modifiable sans nouvelle version.
 * Une valeur vide signifie « non configuré » : les applications masquent alors le canal correspondant.
 */
@RestController
public class ContactPlateformeController {

    public record Contact(String telephone, String whatsapp, String email, String adresse, String horaires) {
    }

    private final Contact contact;

    public ContactPlateformeController(@Value("${dogo.support.telephone:}") String telephone,
                                       @Value("${dogo.support.whatsapp:}") String whatsapp,
                                       @Value("${dogo.support.email:}") String email,
                                       @Value("${dogo.support.adresse:}") String adresse,
                                       @Value("${dogo.support.horaires:}") String horaires) {
        this.contact = new Contact(telephone.strip(), whatsapp.strip(), email.strip(), adresse.strip(), horaires.strip());
    }

    @GetMapping("/api/public/contact")
    public Contact contact() {
        return contact;
    }
}
