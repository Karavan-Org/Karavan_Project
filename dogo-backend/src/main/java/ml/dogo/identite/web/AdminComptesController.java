package ml.dogo.identite.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.Map;
import ml.dogo.identite.application.AdministrateurService;
import ml.dogo.identite.application.CompteService;
import ml.dogo.identite.domain.RoleAdministratif;
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
@RequestMapping("/api/admin")
public class AdminComptesController {

    public record SuspensionRequete(@NotBlank String motif) {
    }

    public record AdministrateurRequete(@NotBlank String telephone, @NotBlank String nom, @NotBlank String pin,
                                        @NotBlank String matricule, @NotNull RoleAdministratif role) {
    }

    private final CompteService comptes;
    private final AdministrateurService administrateurs;

    public AdminComptesController(CompteService comptes, AdministrateurService administrateurs) {
        this.comptes = comptes;
        this.administrateurs = administrateurs;
    }

    @PostMapping("/comptes/{id}/suspension")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('COMPTE_SUSPENDRE')")
    public void suspendre(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id,
                          @Valid @RequestBody SuspensionRequete r) {
        comptes.suspendre(moi.id(), id, r.motif());
    }

    @PostMapping("/comptes/{id}/reactivation")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('COMPTE_SUSPENDRE')")
    public void reactiver(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id) {
        comptes.reactiver(moi.id(), id);
    }

    @PostMapping("/administrateurs")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('ADMIN_CREER')")
    public Map<String, Long> creer(@AuthenticationPrincipal UtilisateurCourant moi,
                                   @Valid @RequestBody AdministrateurRequete r) {
        long id = administrateurs.creerParAdministrateur(moi.id(), r.telephone(), r.nom(), r.pin(), r.matricule(),
                r.role());
        return Map.of("id", id);
    }

    @GetMapping("/commercants")
    @PreAuthorize("hasAnyAuthority('ADMIN_CREER', 'COMPTE_SUSPENDRE', 'KYC_VALIDER', 'AUDIT_LIRE')")
    public List<CompteService.CommercantVue> listerCommercants() {
        return comptes.listerCommercants();
    }

    @GetMapping("/grossistes")
    @PreAuthorize("hasAnyAuthority('ADMIN_CREER', 'COMPTE_SUSPENDRE', 'KYC_VALIDER', 'AUDIT_LIRE')")
    public List<CompteService.GrossisteVue> listerGrossistes() {
        return comptes.listerGrossistes();
    }

    @GetMapping("/courtiers")
    @PreAuthorize("hasAnyAuthority('ADMIN_CREER', 'COMPTE_SUSPENDRE', 'KYC_VALIDER', 'AUDIT_LIRE')")
    public List<CompteService.CourtierVue> listerCourtiers() {
        return comptes.listerCourtiers();
    }

    @GetMapping("/supervision/stats")
    @PreAuthorize("hasAnyAuthority('ADMIN_CREER', 'COMPTE_SUSPENDRE', 'AUDIT_LIRE', 'GROUPE_SUIVRE')")
    public CompteService.SupervisionStatsVue stats() {
        return comptes.statistiques();
    }
}
