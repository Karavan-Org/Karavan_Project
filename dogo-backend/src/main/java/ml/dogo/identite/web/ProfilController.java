package ml.dogo.identite.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import ml.dogo.identite.application.AuthService;
import ml.dogo.identite.application.CompteService;
import ml.dogo.identite.domain.OperateurMobileMoney;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Espace personnel : profil, moyens de paiement Mobile Money, déconnexion. */
@RestController
@RequestMapping("/api/moi")
public class ProfilController {

    public record ProfilRequete(String nom, String langue, String photoUrl) {
    }

    public record PhotoReponse(String photoUrl) {
    }

    public record MoyenRequete(@NotBlank String numero, @NotNull OperateurMobileMoney operateur, boolean parDefaut) {
    }

    private final CompteService comptes;
    private final AuthService auth;

    public ProfilController(CompteService comptes, AuthService auth) {
        this.comptes = comptes;
        this.auth = auth;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PROFIL_GERER')")
    public CompteService.ProfilComplet profil(@AuthenticationPrincipal UtilisateurCourant moi) {
        return comptes.profil(moi.id());
    }

    @PatchMapping
    @PreAuthorize("hasAuthority('PROFIL_GERER')")
    public CompteService.ProfilComplet modifier(@AuthenticationPrincipal UtilisateurCourant moi,
                                                @RequestBody ProfilRequete r) {
        return comptes.modifierProfil(moi.id(), r.nom(), r.langue(), r.photoUrl());
    }

    @PostMapping(value = "/photo", consumes = org.springframework.http.MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('PROFIL_GERER')")
    public PhotoReponse uploaderPhoto(@AuthenticationPrincipal UtilisateurCourant moi,
                                      @org.springframework.web.bind.annotation.RequestParam(value = "photo", required = false) org.springframework.web.multipart.MultipartFile photo,
                                      @org.springframework.web.bind.annotation.RequestParam(value = "fichier", required = false) org.springframework.web.multipart.MultipartFile fichier,
                                      @org.springframework.web.bind.annotation.RequestParam(value = "file", required = false) org.springframework.web.multipart.MultipartFile file) {
        org.springframework.web.multipart.MultipartFile effectif = photo != null ? photo : (fichier != null ? fichier : file);
        if (effectif == null || effectif.isEmpty()) {
            throw new ml.dogo.shared.errors.ErreurMetier(ml.dogo.shared.errors.CodeErreur.DONNEES_INVALIDES, null, "Aucun fichier fourni");
        }
        String url = comptes.enregistrerPhotoProfil(moi.id(), effectif);
        return new PhotoReponse(url);
    }

    public record ChangerMdpRequete(@NotBlank String ancienMotDePasse, @NotBlank String nouveauMotDePasse) {
    }

    @PostMapping("/mot-de-passe")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('PROFIL_GERER')")
    public void changerMotDePasse(@AuthenticationPrincipal UtilisateurCourant moi,
                                 @Valid @RequestBody ChangerMdpRequete r) {
        comptes.changerMotDePasse(moi.id(), r.ancienMotDePasse(), r.nouveauMotDePasse());
    }

    @PostMapping("/deconnexion")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deconnecter(@AuthenticationPrincipal UtilisateurCourant moi) {
        auth.deconnecter(moi.sessionId());
    }

    @GetMapping("/moyens-paiement")
    @PreAuthorize("hasAuthority('PROFIL_GERER')")
    public List<CompteService.MoyenVue> moyens(@AuthenticationPrincipal UtilisateurCourant moi) {
        return comptes.moyens(moi.id());
    }

    @PostMapping("/moyens-paiement")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('PROFIL_GERER')")
    public CompteService.MoyenVue ajouter(@AuthenticationPrincipal UtilisateurCourant moi,
                                          @Valid @RequestBody MoyenRequete r) {
        return comptes.ajouterMoyen(moi.id(), r.numero(), r.operateur(), r.parDefaut());
    }

    @PutMapping("/moyens-paiement/{id}/defaut")
    @PreAuthorize("hasAuthority('PROFIL_GERER')")
    public CompteService.MoyenVue definirParDefaut(@AuthenticationPrincipal UtilisateurCourant moi,
                                                   @PathVariable long id) {
        return comptes.definirParDefaut(moi.id(), id);
    }

    @DeleteMapping("/moyens-paiement/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('PROFIL_GERER')")
    public void supprimer(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id) {
        comptes.supprimerMoyen(moi.id(), id);
    }
}
