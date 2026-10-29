package ml.dogo.logistique.application;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.finance.api.FinanceApi;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.logistique.domain.RegleRetrait;
import ml.dogo.logistique.domain.StatutCommande;
import ml.dogo.logistique.persistence.CodeRetrait;
import ml.dogo.logistique.persistence.CodeRetraitRepository;
import ml.dogo.logistique.persistence.Commande;
import ml.dogo.logistique.persistence.CommandeRepository;
import ml.dogo.logistique.persistence.PointRetrait;
import ml.dogo.logistique.persistence.PointRetraitRepository;
import ml.dogo.logistique.persistence.PreuveRetrait;
import ml.dogo.logistique.persistence.PreuveRetraitRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Codes de retrait et validation du retrait (RG-53 à RG-56).
 *
 * <p>Un retrait verrouille toutes les commandes du groupe, dans l'ordre des identifiants : deux retraits du même groupe
 * se suivent (et le dernier voit que tout est collecté), sans interblocage possible. La ligne du code n'est jamais
 * verrouillée : le compteur d'échecs s'écrit dans une transaction indépendante ({@link CompteursRetrait}).
 */
@Service
public class RetraitService {

    /** Ce que voit le Commerçant : le jeton du QR code seulement. Le PIN n'est jamais relisible (RG-71). */
    public record CodeVue(long commandeId, String qrToken, Instant expiration, int tentativesRestantes, boolean bloque) {
    }

    public record RetraitVue(long commandeId, String statut, Instant date, String mode) {
    }

    private static final SecureRandom ALEA = new SecureRandom();

    private final CommandeRepository commandes;
    private final CodeRetraitRepository codes;
    private final PreuveRetraitRepository preuves;
    private final PointRetraitRepository points;
    private final CompteursRetrait compteurs;
    private final GroupeAchatApi campagne;
    private final FinanceApi finance;
    private final IdentiteApi identite;
    private final AuditApi audit;
    private final NotificationApi notifications;
    private final PasswordEncoder encodeur;
    private final DogoProperties proprietes;
    private final Clock horloge;

    public RetraitService(CommandeRepository commandes, CodeRetraitRepository codes, PreuveRetraitRepository preuves,
                          PointRetraitRepository points, CompteursRetrait compteurs, GroupeAchatApi campagne, FinanceApi finance, IdentiteApi identite,
                          AuditApi audit, NotificationApi notifications, PasswordEncoder encodeur,
                          DogoProperties proprietes, Clock horloge) {
        this.commandes = commandes;
        this.codes = codes;
        this.preuves = preuves;
        this.points = points;
        this.compteurs = compteurs;
        this.campagne = campagne;
        this.finance = finance;
        this.identite = identite;
        this.audit = audit;
        this.notifications = notifications;
        this.encodeur = encodeur;
        this.proprietes = proprietes;
        this.horloge = horloge;
    }

    // ---------------------------------------------------------------------- génération

    /**
     * RG-53 : crée le code unique d'une commande (QR + PIN). Le PIN est envoyé par SMS au Commerçant, une fois la
     * transaction validée, et n'est conservé nulle part sous forme lisible.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public void genererCode(Commande commande, String nomPoint) {
        String lienMap = commande.getPointRetraitId() == null ? null
                : points.findById(commande.getPointRetraitId()).map(PointRetrait::getLienGoogleMap).orElse(null);
        String adresse = commande.getPointRetraitId() == null ? null
                : points.findById(commande.getPointRetraitId()).map(PointRetrait::getAdresse).orElse(null);
        genererCode(commande, nomPoint, lienMap, adresse);
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void genererCode(Commande commande, String nomPoint, String lienGoogleMap, String adresse) {
        String pin = String.format("%06d", ALEA.nextInt(1_000_000));
        byte[] octets = new byte[32];
        ALEA.nextBytes(octets);
        Instant maintenant = horloge.instant();
        Instant expiration = maintenant.plus(proprietes.retrait().validite());
        codes.save(new CodeRetrait(commande.getId(), encodeur.encode(pin), HexFormat.of().formatHex(octets), expiration,
                maintenant));
        long commandeId = commande.getId();
        long commercantId = commande.getCommercantId();

        String mapTexte = (lienGoogleMap != null && !lienGoogleMap.isBlank())
                ? " Localisation Google Maps : " + lienGoogleMap.strip()
                : "";
        String adrTexte = (adresse != null && !adresse.isBlank()) ? " (" + adresse.strip() + ")" : "";

        // Notification in-app affichée en direct pour le commerçant
        String messageInApp = "Colis arrivé au dépôt ! Votre commande #" + commandeId + " est prête au dépôt " + nomPoint + adrTexte + "."
                + mapTexte + " Code PIN : " + pin + " (ou présentez le QR code sur l'application).";
        notifications.notifier(commercantId, messageInApp);

        String telephone = identite.acteur(commercantId).map(IdentiteApi.ActeurInfo::telephone).orElse(null);
        if (telephone != null) {
            String sms = "DoGo : votre commande #" + commandeId + " est disponible au dépôt " + nomPoint + adrTexte + "."
                    + mapTexte + " PIN de retrait : " + pin + " (ou QR code). Valable "
                    + proprietes.retrait().validite().toDays() + " jours.";
            apresValidation(() -> notifications.envoyerSms(telephone, sms));
        }
    }

    /** RG-54 : un code expiré ou bloqué est remplacé. Un code bloqué ne peut l'être que par un administrateur (support). */
    @Transactional
    public CodeVue regenerer(UtilisateurCourant acteur, long commandeId) {
        long groupeId = commandes.groupeDe(commandeId).orElseThrow(() -> ErreurMetier.nonTrouve("Commande", commandeId));
        groupeGere(acteur, groupeId);
        Commande commande = verrouillerCommande(groupeId, commandeId);
        if (commande.getStatut() != StatutCommande.EN_ATTENTE_RETRAIT) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-54",
                    "Seule une commande en attente de retrait a un code à régénérer");
        }
        CodeRetrait ancien = codes.findByCommandeId(commandeId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Code de retrait de la commande", commandeId));
        if (ancien.isUtilise()) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-54", "Ce code a déjà servi");
        }
        boolean expire = !horloge.instant().isBefore(ancien.getExpiration());
        if (!expire && !ancien.isBloque()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-54", "Le code actuel est encore valable");
        }
        if (ancien.isBloque() && !acteur.estAdministrateur()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-54",
                    "Un code bloqué ne peut être remplacé que par un administrateur");
        }
        codes.delete(ancien);
        codes.flush();
        genererCode(commande, nomDuPoint(commande));
        audit.tracer(acteur.id(), "CODE_RETRAIT_REGENERE", "commande=" + commandeId, ancien.isBloque() ? "bloque" : "expire");
        return codeDe(commandeId);
    }

    // ---------------------------------------------------------------------- consultation (Commerçant)

    @Transactional(readOnly = true)
    public CodeVue codeRetrait(long commercantId, long commandeId) {
        Commande c = commandes.findById(commandeId).orElseThrow(() -> ErreurMetier.nonTrouve("Commande", commandeId));
        if (c.getCommercantId() != commercantId) {
            throw ErreurMetier.nonTrouve("Commande", commandeId);
        }
        if (c.getStatut() != StatutCommande.EN_ATTENTE_RETRAIT) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-53",
                    "Le code de retrait n'est disponible que lorsque la commande est prête à être retirée");
        }
        return codeDe(commandeId);
    }

    private CodeVue codeDe(long commandeId) {
        CodeRetrait code = codes.findByCommandeId(commandeId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Code de retrait de la commande", commandeId));
        int restantes = Math.max(0, proprietes.retrait().maxTentatives() - code.getTentatives());
        return new CodeVue(commandeId, code.getQrToken(), code.getExpiration(), restantes, code.isBloque());
    }

    // ---------------------------------------------------------------------- validation du retrait

    /**
     * RG-53 à RG-55 : le Courtier (ou un administrateur) valide le retrait, soit en scannant le QR code, soit en saisissant
     * le numéro de commande et le PIN. À la collecte, dans la même transaction : la commande passe à COLLECTEE, le code
     * est consommé, la preuve est écrite et le séquestre est libéré vers le portefeuille du Courtier.
     * Un PIN erroné augmente le compteur d'échecs (indépendamment de la transaction) ; au maximum, le code se bloque.
     */
    @Transactional
    public RetraitVue valider(UtilisateurCourant acteur, Long commandeIdSaisi, String qrToken, String pin) {
        boolean parQr = qrToken != null && !qrToken.isBlank();
        boolean parPin = pin != null && !pin.isBlank();
        if (parQr == parPin || (parPin && commandeIdSaisi == null)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-53",
                    "Présentez soit le QR code, soit le numéro de commande avec le PIN");
        }
        long commandeId = parQr
                ? codes.commandeDuJeton(qrToken.strip()).orElseThrow(RetraitService::codeInvalide)
                : commandeIdSaisi;
        long groupeId = commandes.groupeDe(commandeId).orElseThrow(RetraitService::codeInvalide);
        GroupeAchatApi.GroupeInfo g = groupeGere(acteur, groupeId);

        List<Commande> duGroupe = commandes.verrouillerDuGroupe(groupeId);
        Commande commande = duGroupe.stream().filter(c -> c.getId() == commandeId).findFirst()
                .orElseThrow(RetraitService::codeInvalide);
        if (commande.getStatut() != StatutCommande.EN_ATTENTE_RETRAIT) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-53",
                    "Cette commande n'est pas en attente de retrait (statut : " + commande.getStatut() + ")");
        }
        CodeRetrait code = codes.findByCommandeId(commandeId).orElseThrow(RetraitService::codeInvalide);
        Instant maintenant = horloge.instant();
        RegleRetrait.verifierUtilisable(code.isUtilise(), code.isBloque(), code.getExpiration(), maintenant);

        int max = proprietes.retrait().maxTentatives();
        if (parPin && !encodeur.matches(pin.strip(), code.getPinHash())) {
            int echecs = compteurs.enregistrerEchec(code.getId(), max);
            if (RegleRetrait.doitBloquer(echecs, max)) {
                throw new ErreurMetier(CodeErreur.CODE_RETRAIT_BLOQUE, "RG-54",
                        "Code bloqué après trop de tentatives : contactez le support");
            }
            throw new ErreurMetier(CodeErreur.CODE_RETRAIT_INVALIDE, "RG-54",
                    "PIN incorrect : il reste " + (max - echecs) + " tentative(s)");
        }

        // Valeurs lues avant les requêtes SQL directes (qui vident le contexte de persistance).
        long participationId = commande.getParticipationId();
        long commercantId = commande.getCommercantId();
        boolean derniere = duGroupe.stream().filter(c -> c.getId() != commandeId)
                .allMatch(c -> c.getStatut() == StatutCommande.COLLECTEE || c.getStatut() == StatutCommande.ANNULEE);
        String mode = parQr ? "QR" : "PIN";

        commande.changerStatut(StatutCommande.COLLECTEE);
        preuves.save(new PreuveRetrait(commandeId, mode, null, maintenant));
        if (codes.consommer(code.getId(), maintenant) != 1) {
            throw new ErreurMetier(CodeErreur.CODE_RETRAIT_INVALIDE, "RG-54", "Ce code n'est plus utilisable");
        }
        finance.libererSequestre(participationId);
        audit.tracer(acteur.id(), "RETRAIT_VALIDE", "commande=" + commandeId, "mode=" + mode + " groupe=" + g.id());
        notifications.notifier(commercantId, "Retrait confirmé pour votre commande #" + commandeId + ". Merci d'avoir utilisé DoGo.");
        if (derniere) {
            campagne.transitionner(groupeId, "TERMINE", "SYSTEME");
            audit.tracer(null, "GROUPE_TERMINE", "groupe=" + groupeId, "toutes les commandes sont collectées");
        }
        return new RetraitVue(commandeId, StatutCommande.COLLECTEE.name(), maintenant, mode);
    }

    // ---------------------------------------------------------------------- utilitaires

    private static ErreurMetier codeInvalide() {
        return new ErreurMetier(CodeErreur.CODE_RETRAIT_INVALIDE, "RG-54", "Code de retrait invalide");
    }

    /** Le Courtier du groupe, ou un administrateur : personne d'autre ne valide un retrait (RG-55). */
    private GroupeAchatApi.GroupeInfo groupeGere(UtilisateurCourant acteur, long groupeId) {
        GroupeAchatApi.GroupeInfo g = campagne.groupe(groupeId).orElseThrow(RetraitService::codeInvalide);
        if (!acteur.estAdministrateur() && (g.porteParGrossiste() || g.courtierId() != acteur.id())) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-55",
                    "Seul le courtier de ce groupe peut valider le retrait");
        }
        return g;
    }

    private Commande verrouillerCommande(long groupeId, long commandeId) {
        return commandes.verrouillerDuGroupe(groupeId).stream().filter(c -> c.getId() == commandeId).findFirst()
                .orElseThrow(() -> ErreurMetier.nonTrouve("Commande", commandeId));
    }

    private String nomDuPoint(Commande commande) {
        return commande.getPointRetraitId() == null ? "DoGo"
                : points.findById(commande.getPointRetraitId()).map(p -> p.getNom()).orElse("DoGo");
    }

    /** Exécute l'action une fois la transaction validée (un SMS ne doit pas partir pour une opération annulée). */
    static void apresValidation(Runnable action) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    action.run();
                }
            });
        } else {
            action.run();
        }
    }
}

