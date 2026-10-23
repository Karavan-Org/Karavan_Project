package ml.dogo.identite.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import ml.dogo.identite.application.SupportAdminService;
import ml.dogo.litige.api.LitigeApi;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Gestion du support client et partage d'informations entre administrateurs (Admin Support & Admin Technique).
 */
@RestController
@RequestMapping("/api/admin/support")
public class SupportAdminController {

    public record MessageUtilisateurRequete(@NotNull Long destinataireId, @NotBlank String message) {}
    public record DiffusionAdminsRequete(@NotBlank String sujet, @NotBlank String message) {}

    private final SupportAdminService support;

    public SupportAdminController(SupportAdminService support) {
        this.support = support;
    }

    @PostMapping("/message-utilisateur")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyAuthority('COMPTE_SUSPENDRE', 'ADMIN_CREER')")
    public void envoyerMessageUtilisateur(@AuthenticationPrincipal UtilisateurCourant moi,
                                          @Valid @RequestBody MessageUtilisateurRequete r) {
        support.envoyerMessageUtilisateur(moi.id(), r.destinataireId(), r.message());
    }

    @PostMapping("/diffuser-admins")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyAuthority('COMPTE_SUSPENDRE', 'ADMIN_CREER')")
    public void diffuserAdmins(@AuthenticationPrincipal UtilisateurCourant moi,
                               @Valid @RequestBody DiffusionAdminsRequete r) {
        support.diffuserAdmins(moi.id(), r.sujet(), r.message());
    }

    @GetMapping("/litiges")
    @PreAuthorize("hasAnyAuthority('COMPTE_SUSPENDRE', 'ADMIN_CREER', 'REMBOURSEMENT_APPROUVER')")
    public List<LitigeApi.LitigeInfo> listerLitiges() {
        return support.listerLitiges();
    }
}
