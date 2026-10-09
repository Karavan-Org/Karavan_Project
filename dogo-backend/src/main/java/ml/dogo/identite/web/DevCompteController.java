package ml.dogo.identite.web;

import java.util.Map;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import org.springframework.context.annotation.Profile;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Contrôleur de commodité pour l'environnement de développement / test (profil « demo »).
 * Permet d'activer instantanément un compte utilisateur ou grossiste sans passer par le backoffice.
 */
@Profile("demo")
@PreAuthorize("hasAuthority('ADMIN_CREER')")
@RestController
@RequestMapping("/api/dev")
public class DevCompteController {

    private final UtilisateurRepository utilisateurs;

    public DevCompteController(UtilisateurRepository utilisateurs) {
        this.utilisateurs = utilisateurs;
    }

    @PostMapping("/activer-compte/{id}")
    @ResponseStatus(HttpStatus.OK)
    @Transactional
    public Map<String, Object> activerCompte(@PathVariable long id) {
        Utilisateur u = utilisateurs.findById(id).orElse(null);
        if (u != null) {
            if (u.getStatutCompte() != StatutCompte.ACTIF) {
                u.changerStatut(StatutCompte.ACTIF);
            }
            u.marquerTelephoneVerifie();
            return Map.of("succes", true, "id", id, "statut", "ACTIF");
        }
        return Map.of("succes", false, "message", "Utilisateur non trouvé");
    }

    @PostMapping("/activer-compte-par-telephone/{telephone}")
    @ResponseStatus(HttpStatus.OK)
    @Transactional
    public Map<String, Object> activerCompteParTelephone(@PathVariable String telephone) {
        String normalise = telephone.startsWith("+") ? telephone : "+" + telephone.trim();
        Utilisateur u = utilisateurs.findByTelephone(normalise).orElse(null);
        if (u != null) {
            if (u.getStatutCompte() != StatutCompte.ACTIF) {
                u.changerStatut(StatutCompte.ACTIF);
            }
            u.marquerTelephoneVerifie();
            return Map.of("succes", true, "telephone", normalise, "statut", "ACTIF");
        }
        return Map.of("succes", false, "message", "Utilisateur non trouvé");
    }
}

