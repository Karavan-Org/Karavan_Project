package ml.dogo.identite.web;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import ml.dogo.identite.application.KycService;
import ml.dogo.identite.domain.StatutValidation;
import ml.dogo.identite.domain.TypeDocument;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api")
public class KycController {

    public record DecisionRequete(@NotNull StatutValidation decision, String commentaire) {
    }

    public record ValidationCompteRequete(String commentaire) {
    }

    private final KycService kyc;

    public KycController(KycService kyc) {
        this.kyc = kyc;
    }

    /** Dépôt du dossier : {@code types[i]} décrit {@code fichiers[i]}. */
    @PostMapping(value = "/kyc", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('KYC_SOUMETTRE')")
    public KycService.DossierVue soumettre(@AuthenticationPrincipal UtilisateurCourant moi,
                                           @RequestParam("types") List<TypeDocument> types,
                                           @RequestParam("fichiers") List<MultipartFile> fichiers) throws IOException {
        if (types.size() != fichiers.size()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-04", "Un type de document par fichier");
        }
        List<KycService.PieceJointe> pieces = new ArrayList<>();
        for (int i = 0; i < fichiers.size(); i++) {
            pieces.add(new KycService.PieceJointe(types.get(i), fichiers.get(i).getOriginalFilename(),
                    fichiers.get(i).getBytes()));
        }
        return kyc.soumettre(moi.id(), pieces);
    }

    @GetMapping("/kyc/moi")
    @PreAuthorize("hasAuthority('KYC_SOUMETTRE')")
    public KycService.DossierVue monDossier(@AuthenticationPrincipal UtilisateurCourant moi) {
        return kyc.monDossier(moi.id());
    }

    @GetMapping("/admin/kyc")
    @PreAuthorize("hasAuthority('KYC_VALIDER')")
    public List<KycService.DossierVue> enAttente() {
        return kyc.enAttente();
    }

    /** Valide le compte d'un grossiste ou d'un courtier : dossier en attente approuvé, ou validation manuelle tracée. */
    @PostMapping("/admin/kyc/utilisateurs/{utilisateurId}/validation")
    @PreAuthorize("hasAuthority('KYC_VALIDER')")
    public KycService.DossierVue validerCompte(@AuthenticationPrincipal UtilisateurCourant moi,
                                               @PathVariable long utilisateurId,
                                               @RequestBody ValidationCompteRequete r) {
        return kyc.validerCompte(moi.id(), utilisateurId, r.commentaire());
    }

    @GetMapping("/admin/kyc/utilisateurs/{utilisateurId}")
    @PreAuthorize("hasAnyAuthority('KYC_VALIDER', 'COMPTE_SUSPENDRE', 'AUDIT_LIRE')")
    public List<KycService.DossierVue> dossiersDe(@PathVariable long utilisateurId) {
        return kyc.dossiersDe(utilisateurId);
    }

    @PostMapping("/admin/kyc/{dossierId}/decision")
    @PreAuthorize("hasAuthority('KYC_VALIDER')")
    public KycService.DossierVue decider(@AuthenticationPrincipal UtilisateurCourant moi,
                                         @PathVariable long dossierId, @Valid @RequestBody DecisionRequete r) {
        return kyc.decider(moi.id(), dossierId, r.decision(), r.commentaire());
    }

    @GetMapping("/admin/kyc/{dossierId}/documents/{documentId}")
    @PreAuthorize("hasAuthority('KYC_VALIDER')")
    public ResponseEntity<byte[]> document(@AuthenticationPrincipal UtilisateurCourant moi,
                                           @PathVariable long dossierId, @PathVariable long documentId) {
        KycService.FichierVue f = kyc.lireDocument(moi.id(), dossierId, documentId);
        String nom = f.nom().toLowerCase(java.util.Locale.ROOT);
        String extension = nom.contains(".") ? nom.substring(nom.lastIndexOf('.')) : "";
        MediaType type = switch (extension) {
            case ".pdf" -> MediaType.APPLICATION_PDF;
            case ".png" -> MediaType.IMAGE_PNG;
            case ".jpg", ".jpeg" -> MediaType.IMAGE_JPEG;
            case ".txt" -> new MediaType("text", "plain", java.nio.charset.StandardCharsets.UTF_8);
            case ".csv" -> new MediaType("text", "csv", java.nio.charset.StandardCharsets.UTF_8);
            case ".rtf" -> MediaType.parseMediaType("application/rtf");
            case ".doc" -> MediaType.parseMediaType("application/msword");
            case ".docx" -> MediaType.parseMediaType(
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
            case ".xls" -> MediaType.parseMediaType("application/vnd.ms-excel");
            case ".xlsx" -> MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
            case ".odt" -> MediaType.parseMediaType("application/vnd.oasis.opendocument.text");
            case ".ods" -> MediaType.parseMediaType("application/vnd.oasis.opendocument.spreadsheet");
            default -> MediaType.APPLICATION_OCTET_STREAM;
        };
        // Images, PDF et texte s'affichent dans la console ; les fichiers bureautiques se téléchargent
        boolean apercu = type.getType().equals("image") || type.getType().equals("text")
                || type.equals(MediaType.APPLICATION_PDF);
        return ResponseEntity.ok().contentType(type)
                .header("X-Content-Type-Options", "nosniff")
                .header("Content-Disposition", (apercu ? "inline" : "attachment") + "; filename=\"" + f.nom() + "\"")
                .body(f.contenu());
    }
}
