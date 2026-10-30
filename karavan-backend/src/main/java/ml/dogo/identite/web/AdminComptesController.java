package ml.dogo.identite.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.Map;
import ml.dogo.identite.application.AdministrateurService;
import ml.dogo.identite.application.AuthService;
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

    /** Tous les rôles administratifs consultent les comptes : le support pour les retraits, la finance pour les litiges. */
    private static final String LECTURE_COMPTES = "hasAnyAuthority('ADMIN_CREER', 'COMPTE_SUSPENDRE', 'KYC_VALIDER', "
            + "'AUDIT_LIRE', 'RECEPTION_VALIDER', 'REMBOURSEMENT_APPROUVER')";

    public record SuspensionRequete(@NotBlank String motif) {
    }

    /** {@code motDePasse} : provisoire, le nouvel administrateur le remplace à sa première connexion (RG-07b). */
    public record AdministrateurRequete(@NotBlank String telephone, @NotBlank String nom, @Email String email,
                                        String motDePasse, String pin,
                                        @NotBlank String matricule, @NotNull RoleAdministratif role) {
        public String motDePasseEffectif() {
            return motDePasse != null && !motDePasse.isBlank() ? motDePasse : pin;
        }
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
        long id = administrateurs.creerParAdministrateur(moi.id(), r.telephone(), r.nom(), r.email(),
                r.motDePasseEffectif(), r.matricule(), r.role());
        return Map.of("id", id);
    }

    /** Fonction administrative → ce qu'elle permet : affiché dans la console au moment de créer un administrateur. */
    public record FonctionAdministrativeVue(String role, String libelle, String mission, List<String> permissions,
                                            boolean attribuable) {
    }

    @GetMapping("/fonctions-administratives")
    @PreAuthorize("hasAuthority('ADMIN_CREER')")
    public List<FonctionAdministrativeVue> fonctionsAdministratives() {
        return java.util.Arrays.stream(RoleAdministratif.values())
                .map(r -> new FonctionAdministrativeVue(r.name(), r.libelle(), r.mission(),
                        AuthService.permissionsAdministratives(r), r != RoleAdministratif.TECHNIQUE))
                .toList();
    }

    @GetMapping("/administrateurs")
    @PreAuthorize("hasAuthority('ADMIN_CREER')")
    public List<CompteService.AdministrateurVue> listerAdministrateurs() {
        return comptes.listerAdministrateurs();
    }

    @GetMapping("/commercants")
    @PreAuthorize(LECTURE_COMPTES)
    public List<CompteService.CommercantVue> listerCommercants() {
        return comptes.listerCommercants();
    }

    @GetMapping("/grossistes")
    @PreAuthorize(LECTURE_COMPTES)
    public List<CompteService.GrossisteVue> listerGrossistes() {
        return comptes.listerGrossistes();
    }

    @GetMapping("/courtiers")
    @PreAuthorize(LECTURE_COMPTES)
    public List<CompteService.CourtierVue> listerCourtiers() {
        return comptes.listerCourtiers();
    }

    @GetMapping("/supervision/stats")
    @PreAuthorize("hasAnyAuthority('ADMIN_CREER', 'COMPTE_SUSPENDRE', 'AUDIT_LIRE', 'GROUPE_SUIVRE')")
    public CompteService.SupervisionStatsVue stats() {
        return comptes.statistiques();
    }
}
