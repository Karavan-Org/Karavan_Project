package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.finance.domain.RegleFinance;
import ml.dogo.finance.domain.TypeMouvement;
import ml.dogo.finance.persistence.MouvementFinancier;
import ml.dogo.finance.persistence.MouvementFinancierRepository;
import ml.dogo.finance.persistence.PorteFeuilleCourtier;
import ml.dogo.finance.persistence.PorteFeuilleCourtierRepository;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Portefeuille du Courtier / Commerçant / Grossiste : consultation, recharge, dépense et retrait (RG-41). */
@Service
public class PortefeuilleService {

    public record PortefeuilleVue(BigDecimal soldeBloque, BigDecimal soldeDisponible, String devise) {
    }

    public record MouvementVue(long id, String type, BigDecimal montant, Instant date, String reference) {
    }

    private final PorteFeuilleCourtierRepository portefeuilles;
    private final MouvementFinancierRepository journal;
    private final MouvementService mouvements;
    private final IdentiteApi identite;
    private final PasserelleMobileMoney passerelle;
    private final AuditApi audit;
    private final NotificationApi notifications;

    public PortefeuilleService(PorteFeuilleCourtierRepository portefeuilles, MouvementFinancierRepository journal,
                               MouvementService mouvements, IdentiteApi identite, PasserelleMobileMoney passerelle,
                               AuditApi audit, NotificationApi notifications) {
        this.portefeuilles = portefeuilles;
        this.journal = journal;
        this.mouvements = mouvements;
        this.identite = identite;
        this.passerelle = passerelle;
        this.audit = audit;
        this.notifications = notifications;
    }

    @Transactional
    public PortefeuilleVue voir(long courtierId) {
        PorteFeuilleCourtier p = mouvements.portefeuilleDe(courtierId);
        return new PortefeuilleVue(p.getSoldeBloque(), p.getSoldeDisponible(), p.getDevise());
    }

    @Transactional
    public List<MouvementVue> mouvements(long courtierId, int taille) {
        long id = mouvements.portefeuilleDe(courtierId).getId();
        return journal.findByPortefeuilleIdOrderByIdDesc(id, PageRequest.of(0, Math.min(Math.max(taille, 1), 200))).stream()
                .map(PortefeuilleService::vue).toList();
    }

    /**
     * RG-41 : retrait du solde disponible vers un numéro Mobile Money du Courtier. La clé d'idempotence évite un double
     * retrait si la requête est rejouée ; le solde bloqué reste intouchable.
     */
    @Transactional
    public PortefeuilleVue retirer(long courtierId, BigDecimal montant, Long moyenId, String cle) {
        IdentiteApi.ActeurInfo acteur = identite.exigerActif(courtierId);
        // Le porteur d'un groupe encaisse : le courtier, ou le grossiste qui monte ses propres groupes
        if (!"COURTIER".equals(acteur.type()) && !"GROSSISTE".equals(acteur.type())) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-41", "Réservé aux courtiers et aux grossistes");
        }
        if (cle == null || cle.isBlank() || cle.length() > 60) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-41", "La clé d'idempotence est obligatoire");
        }
        String reference = "RETRAIT-" + courtierId + "-" + cle;
        PorteFeuilleCourtier p = mouvements.portefeuilleDe(courtierId);
        if (journal.existsByReference(reference)) {
            return new PortefeuilleVue(p.getSoldeBloque(), p.getSoldeDisponible(), p.getDevise());
        }
        RegleFinance.verifierRetrait(p.getSoldeDisponible(), montant);
        IdentiteApi.MoyenPaiementInfo moyen = moyenId != null
                ? identite.moyenPaiementDe(courtierId, moyenId)
                : identite.moyenParDefaut(courtierId).orElseThrow(() -> new ErreurMetier(CodeErreur.DONNEES_INVALIDES,
                        "RG-41", "Aucun compte Mobile Money enregistré pour recevoir le retrait"));
        long portefeuilleId = p.getId();
        if (portefeuilles.retirer(portefeuilleId, montant) != 1) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-41", "Solde disponible insuffisant");
        }
        mouvements.enregistrer(null, portefeuilleId, TypeMouvement.RETRAIT_COURTIER, montant, reference);
        audit.tracer(courtierId, "RETRAIT_COURTIER", "portefeuille=" + portefeuilleId, "montant=" + montant);
        passerelle.verser(reference, moyen.numero(), moyen.operateur(), montant);
        PorteFeuilleCourtier apres = mouvements.portefeuilleDe(courtierId);
        return new PortefeuilleVue(apres.getSoldeBloque(), apres.getSoldeDisponible(), apres.getDevise());
    }

    /** Recharge dynamique du portefeuille (Commerçant / Courtier) via Mobile Money (Orange, Moov, Wave). */
    @Transactional
    public PortefeuilleVue recharger(long utilisateurId, BigDecimal montant, String operateur, String numeroTelephone) {
        if (montant == null || montant.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-41", "Le montant de recharge doit être positif");
        }
        PorteFeuilleCourtier p = mouvements.portefeuilleDe(utilisateurId);
        long portefeuilleId = p.getId();
        portefeuilles.crediterDisponible(portefeuilleId, montant);
        String op = (operateur != null && !operateur.isBlank()) ? operateur : "Mobile Money";
        String reference = "RECH-" + utilisateurId + "-" + System.currentTimeMillis();
        mouvements.enregistrer(null, portefeuilleId, TypeMouvement.RECHARGE_PORTEFEUILLE, montant, reference);
        audit.tracer(utilisateurId, "RECHARGE_PORTEFEUILLE", "portefeuille=" + portefeuilleId, "montant=" + montant);
        notifications.notifier(utilisateurId, "Votre portefeuille a été rechargé de " + montant.toBigInteger() + " FCFA via " + op + ".");
        PorteFeuilleCourtier apres = portefeuilles.findById(portefeuilleId).orElseThrow();
        return new PortefeuilleVue(apres.getSoldeBloque(), apres.getSoldeDisponible(), apres.getDevise());
    }

    private static MouvementVue vue(MouvementFinancier m) {
        return new MouvementVue(m.getId(), m.getType().name(), m.getMontant(), m.getDateMouvement(), m.getReference());
    }
}
