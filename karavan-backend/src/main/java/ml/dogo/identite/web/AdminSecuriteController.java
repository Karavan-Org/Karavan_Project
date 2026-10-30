package ml.dogo.identite.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.Map;
import ml.dogo.identite.application.AdminSecuriteService;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoints sécurisés pour la configuration et la vérification du code de sécurité à 4 chiffres
 * requis pour chaque action critique d'administration Karavan.
 */
@RestController
@RequestMapping("/api/admin/securite")
// Tout administrateur, quelles que soient ses permissions, gère son propre code de sécurité
@PreAuthorize("hasRole('ADMINISTRATEUR')")
public class AdminSecuriteController {

    public record ConfigurerCodeRequete(
            @NotBlank @Pattern(regexp = "^\\d{4}$", message = "Le code doit comporter exactement 4 chiffres")
            String nouveauCode,
            String ancienCode,
            String motDePasse
    ) {}

    public record VerifierCodeRequete(
            @NotBlank @Pattern(regexp = "^\\d{4}$", message = "Le code doit comporter exactement 4 chiffres")
            String code
    ) {}

    private final AdminSecuriteService adminSecurite;

    public AdminSecuriteController(AdminSecuriteService adminSecurite) {
        this.adminSecurite = adminSecurite;
    }

    @GetMapping("/statut")
    public AdminSecuriteService.StatutSecuriteVue statut(@AuthenticationPrincipal UtilisateurCourant moi) {
        return adminSecurite.obtenirStatut(moi.id());
    }

    @PostMapping("/configurer")
    public ResponseEntity<Map<String, Object>> configurer(@AuthenticationPrincipal UtilisateurCourant moi,
                                                          @Valid @RequestBody ConfigurerCodeRequete r) {
        adminSecurite.configurerCode(moi.id(), r.nouveauCode(), r.ancienCode(), r.motDePasse());
        return ResponseEntity.ok(Map.of(
                "statut", "SUCCES",
                "message", "Code de sécurité à 4 chiffres configuré avec succès.",
                "configure", true
        ));
    }

    @PostMapping("/verifier")
    public ResponseEntity<Map<String, Object>> verifier(@AuthenticationPrincipal UtilisateurCourant moi,
                                                        @Valid @RequestBody VerifierCodeRequete r) {
        adminSecurite.verifierCode(moi.id(), r.code());
        return ResponseEntity.ok(Map.of(
                "valide", true,
                "message", "Code de sécurité validé."
        ));
    }
}

