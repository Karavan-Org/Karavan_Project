package ml.dogo.identite.application;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.StatutValidation;
import ml.dogo.identite.domain.TypeDocument;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.DocumentLegal;
import ml.dogo.identite.persistence.DossierKyc;
import ml.dogo.identite.persistence.DossierKycRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.identite.persistence.ValidationCourtier;
import ml.dogo.identite.persistence.ValidationCourtierRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.stockage.StockageFichiers;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Dossier KYC des Grossistes et Courtiers : soumission (RG-04) et décision d'un administrateur (RG-05). */
@Service
public class KycService {

    public record PieceJointe(TypeDocument type, String nomOriginal, byte[] contenu) {
    }

    public record DocumentVue(long id, String type, String empreinteSha256) {
    }

    public record DossierVue(long id, long utilisateurId, String nom, String telephone, String typeActeur,
                             String statut, java.time.Instant dateSoumission, String motifRejet,
                             List<DocumentVue> documents) {
    }

    public record FichierVue(String nom, byte[] contenu) {
    }

    private final DossierKycRepository dossiers;
    private final ValidationCourtierRepository validations;
    private final UtilisateurRepository utilisateurs;
    private final StockageFichiers stockage;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final Clock horloge;

    public KycService(DossierKycRepository dossiers, ValidationCourtierRepository validations,
                      UtilisateurRepository utilisateurs, StockageFichiers stockage, AuditApi audit,
                      NotificationApi notifications, Clock horloge) {
        this.dossiers = dossiers;
        this.validations = validations;
        this.utilisateurs = utilisateurs;
        this.stockage = stockage;
        this.audit = audit;
        this.notifications = notifications;
        this.horloge = horloge;
    }

    /** RG-03 / RG-04 : un Grossiste ou un Courtier dépose ses pièces ; l'empreinte SHA-256 de chacune est conservée. */
    @Transactional
    public DossierVue soumettre(long utilisateurId, List<PieceJointe> pieces) {
        Utilisateur u = utilisateurs.findById(utilisateurId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Utilisateur", utilisateurId));
        if (!u.typeActeur().exigeKyc()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-03", "Ce type de compte n'a pas de dossier KYC");
        }
        if (u.getStatutCompte() != StatutCompte.EN_ATTENTE) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-03", "Votre compte n'attend pas de validation");
        }
        if (dossiers.existsByUtilisateurIdAndStatut(utilisateurId, StatutValidation.EN_ATTENTE)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-05", "Un dossier est déjà en cours d'examen");
        }
        if (pieces == null || pieces.isEmpty()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-04", "Aucune pièce jointe");
        }
        Set<TypeDocument> fournis = new HashSet<>();
        List<String> extensions = new java.util.ArrayList<>();
        for (PieceJointe p : pieces) {
            String extension = FormatPiece.extensionValidee(p.nomOriginal(), p.contenu());
            if (p.type() == null || extension == null) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-04",
                        "Pièce invalide : formats acceptés " + FormatPiece.FORMATS_LISIBLES);
            }
            fournis.add(p.type());
            extensions.add(extension);
        }
        Set<TypeDocument> manquants = EnumSet.noneOf(TypeDocument.class);
        manquants.addAll(TypeDocument.obligatoiresPour(u.typeActeur()));
        manquants.removeAll(fournis);
        if (!manquants.isEmpty()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-04", "Pièces manquantes : " + manquants);
        }
        DossierKyc dossier = new DossierKyc(utilisateurId, horloge.instant());
        for (int i = 0; i < pieces.size(); i++) {
            PieceJointe p = pieces.get(i);
            // L'extension stockée est celle du format reconnu, jamais celle annoncée par le client
            String cle = stockage.enregistrer("piece" + extensions.get(i), p.contenu());
            dossier.ajouter(new DocumentLegal(p.type(), cle, sha256(p.contenu()), null));
        }
        dossier = dossiers.save(dossier);
        audit.tracer(utilisateurId, "KYC_SOUMIS", null, "dossier=" + dossier.getId() + ", pieces=" + pieces.size());
        for (Long admin : identifiantsValidateurs()) {
            notifications.notifier(admin, "Nouveau dossier KYC à examiner (" + u.getNom() + ").");
        }
        return vue(dossier, u);
    }

    /**
     * RG-05 : un administrateur VALIDATION (ou TECHNIQUE, super-administrateur) décide ; un rejet exige un motif.
     */
    @Transactional
    public DossierVue decider(long administrateurId, long dossierId, StatutValidation decision, String commentaire) {
        exigerValidateur(administrateurId);
        DossierKyc dossier = dossiers.trouverPourDecision(dossierId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Dossier KYC", dossierId));
        dossier.decider(decision, commentaire);
        validations.save(new ValidationCourtier(dossierId, administrateurId, decision, horloge.instant(), commentaire));
        Utilisateur u = utilisateurs.findById(dossier.getUtilisateurId())
                .orElseThrow(() -> ErreurMetier.nonTrouve("Utilisateur", dossier.getUtilisateurId()));
        if (decision == StatutValidation.APPROUVE && u.getStatutCompte() == StatutCompte.EN_ATTENTE) {
            u.changerStatut(StatutCompte.ACTIF);
        }
        audit.tracer(administrateurId, "KYC_" + decision, "dossier=" + dossierId + ", utilisateur=" + u.getId(),
                "statut_compte=" + u.getStatutCompte());
        notifications.notifier(u.getId(), decision == StatutValidation.APPROUVE
                ? "Votre dossier a été approuvé : votre compte DoGo est actif."
                : "Votre dossier a été rejeté. Motif : " + commentaire + ". Vous pouvez le déposer à nouveau.");
        return vue(dossier, u);
    }

    @Transactional(readOnly = true)
    public List<DossierVue> enAttente() {
        return dossiers.findByStatutOrderByDateSoumissionAsc(StatutValidation.EN_ATTENTE).stream()
                .map(d -> vue(d, utilisateurs.findById(d.getUtilisateurId()).orElseThrow())).toList();
    }

    /**
     * Validation d'un compte Grossiste / Courtier par l'administrateur (RG-03, RG-05) : le dossier en attente est
     * approuvé ; sans dossier (pièces vérifiées hors application, comptes créés avant le KYC), une validation
     * manuelle est enregistrée comme dossier approuvé, tracée avec son motif. Le compte en attente devient actif ;
     * un compte suspendu le reste (il se réactive ensuite, RG-09).
     */
    @Transactional
    public DossierVue validerCompte(long administrateurId, long utilisateurId, String commentaire) {
        exigerValidateur(administrateurId);
        Utilisateur u = utilisateurs.findById(utilisateurId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Utilisateur", utilisateurId));
        if (!u.typeActeur().exigeKyc()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-03",
                    "Seuls les grossistes et les courtiers passent par la validation KYC");
        }
        if (commentaire == null || commentaire.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-05", "Indiquez ce qui a été vérifié");
        }
        List<DossierKyc> historique = dossiers.findByUtilisateurIdOrderByDateSoumissionDesc(utilisateurId);
        DossierKyc approuve = historique.stream().filter(d -> d.getStatut() == StatutValidation.APPROUVE).findFirst()
                .orElse(null);
        if (approuve != null) {
            if (u.getStatutCompte() == StatutCompte.EN_ATTENTE) {
                u.changerStatut(StatutCompte.ACTIF);
            }
            return vue(approuve, u);
        }
        DossierKyc enAttente = historique.stream().filter(d -> d.getStatut() == StatutValidation.EN_ATTENTE)
                .findFirst().orElse(null);
        if (enAttente == null) {
            enAttente = dossiers.save(new DossierKyc(utilisateurId, horloge.instant()));
            audit.tracer(administrateurId, "KYC_VALIDATION_MANUELLE", "utilisateur=" + utilisateurId,
                    "dossier=" + enAttente.getId() + ", " + commentaire.strip());
        }
        return decider(administrateurId, enAttente.getId(), StatutValidation.APPROUVE, commentaire.strip());
    }

    private void exigerValidateur(long administrateurId) {
        Administrateur admin = utilisateurs.findById(administrateurId)
                .filter(x -> x instanceof Administrateur).map(x -> (Administrateur) x)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-05", "Réservé aux administrateurs"));
        if (admin.getRoleAdministratif() != RoleAdministratif.VALIDATION
                && admin.getRoleAdministratif() != RoleAdministratif.TECHNIQUE) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-05",
                    "Seul un administrateur VALIDATION ou TECHNIQUE peut décider d'un dossier");
        }
    }

    /** Historique des dossiers d'un acteur, du plus récent au plus ancien (fiche utilisateur de l'administrateur). */
    @Transactional(readOnly = true)
    public List<DossierVue> dossiersDe(long utilisateurId) {
        Utilisateur u = utilisateurs.findById(utilisateurId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Utilisateur", utilisateurId));
        return dossiers.findByUtilisateurIdOrderByDateSoumissionDesc(utilisateurId).stream().map(d -> vue(d, u)).toList();
    }

    @Transactional(readOnly = true)
    public DossierVue monDossier(long utilisateurId) {
        DossierKyc d = dossiers.findFirstByUtilisateurIdOrderByDateSoumissionDesc(utilisateurId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Dossier KYC de l'utilisateur", utilisateurId));
        return vue(d, utilisateurs.findById(utilisateurId).orElseThrow());
    }

    /** Consultation d'une pièce par un administrateur : tracée, car ce sont des données personnelles. */
    @Transactional
    public FichierVue lireDocument(long administrateurId, long dossierId, long documentId) {
        DossierKyc d = dossiers.findById(dossierId).orElseThrow(() -> ErreurMetier.nonTrouve("Dossier KYC", dossierId));
        DocumentLegal doc = d.getDocuments().stream().filter(x -> x.getId().equals(documentId)).findFirst()
                .orElseThrow(() -> ErreurMetier.nonTrouve("Document", documentId));
        audit.tracer(administrateurId, "KYC_DOCUMENT_CONSULTE", null, "dossier=" + dossierId + ", document=" + documentId);
        return new FichierVue(doc.getFichier(), stockage.lire(doc.getFichier()));
    }

    private List<Long> identifiantsValidateurs() {
        return utilisateurs.identifiantsAdministrateursActifs();
    }

    private DossierVue vue(DossierKyc d, Utilisateur u) {
        return new DossierVue(d.getId(), u.getId(), u.getNom(), u.getTelephone(), u.typeActeur().name(),
                d.getStatut().name(), d.getDateSoumission(), d.getMotifRejet(),
                d.getDocuments().stream()
                        .map(x -> new DocumentVue(x.getId(), x.getType().name(), x.getEmpreinteSha256())).toList());
    }

    static String sha256(byte[] contenu) {
        try {
            return java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(contenu));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
