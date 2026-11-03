package ml.dogo.logistique.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.logistique.domain.StatutExpedition;
import ml.dogo.logistique.persistence.EvenementLogistique;
import ml.dogo.logistique.persistence.EvenementLogistiqueRepository;
import ml.dogo.logistique.persistence.Expedition;
import ml.dogo.logistique.persistence.ExpeditionRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gestion du suivi des convois et expéditions internationales (RG-46, écran suivi.svg).
 */
@Service
public class ConvoiService {

    public record CreationDemande(Long groupeId, String reference, String transporteur) {
    }

    public record EvenementDemande(String statut, String localisation) {
    }

    public record EvenementVue(Long id, String statut, String localisation, Instant date) {
    }

    public record ConvoiVue(Long id, Long groupeId, String reference, String statut, Instant dateDepart,
                            String transporteur, List<EvenementVue> evenements) {
    }

    private final ExpeditionRepository expeditions;
    private final EvenementLogistiqueRepository evenements;
    private final GroupeAchatApi groupes;
    private final ParticipationApi participations;
    private final NotificationApi notifications;
    private final Clock horloge;

    public ConvoiService(ExpeditionRepository expeditions,
                         EvenementLogistiqueRepository evenements,
                         GroupeAchatApi groupes,
                         ParticipationApi participations,
                         NotificationApi notifications,
                         Clock horloge) {
        this.expeditions = expeditions;
        this.evenements = evenements;
        this.groupes = groupes;
        this.participations = participations;
        this.notifications = notifications;
        this.horloge = horloge;
    }

    @Transactional(readOnly = true)
    public List<ConvoiVue> lister(UtilisateurCourant moi) {
        if (moi == null) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, null, "Authentification requise");
        }
        if (moi.estAdministrateur()) {
            return expeditions.findAll().stream().map(this::versVue).toList();
        }
        List<Long> groupeIds = switch (moi.type()) {
            case "COURTIER" -> groupes.groupeIdsParCourtier(moi.id());
            case "GROSSISTE" -> groupes.groupeIdsParGrossiste(moi.id());
            case "COMMERCANT" -> participations.groupeIdsParCommercant(moi.id());
            default -> List.of();
        };
        if (groupeIds.isEmpty()) {
            return List.of();
        }
        return expeditions.findByGroupeIdIn(groupeIds).stream().map(this::versVue).toList();
    }

    @Transactional(readOnly = true)
    public ConvoiVue detail(long id, UtilisateurCourant moi) {
        if (moi == null) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, null, "Authentification requise");
        }
        Expedition e = expeditions.findById(id)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", id));
        if (!moi.estAdministrateur()) {
            boolean autorise = switch (moi.type()) {
                case "COURTIER" -> {
                    GroupeAchatApi.GroupeInfo g = groupes.groupe(e.getGroupeId()).orElse(null);
                    yield g != null && !g.porteParGrossiste() && g.courtierId() == moi.id();
                }
                case "GROSSISTE" -> {
                    GroupeAchatApi.GroupeInfo g = groupes.groupe(e.getGroupeId()).orElse(null);
                    yield g != null && g.grossisteId() == moi.id();
                }
                case "COMMERCANT" -> participations.groupeIdsParCommercant(moi.id()).contains(e.getGroupeId());
                default -> false;
            };
            if (!autorise) {
                throw new ErreurMetier(CodeErreur.ACCES_REFUSE, null, "Accès refusé à ce convoi");
            }
        }
        return versVue(e);
    }

    @Transactional
    public ConvoiVue creer(CreationDemande d, UtilisateurCourant moi) {
        if (moi == null) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, null, "Authentification requise");
        }
        if (d.groupeId() == null) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "Le groupeId est obligatoire");
        }
        if (d.reference() == null || d.reference().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "La référence du convoi est obligatoire");
        }
        GroupeAchatApi.GroupeInfo g = groupes.groupe(d.groupeId())
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", d.groupeId()));
        // Les droits d'abord : un acteur non habilité n'apprend rien de l'état du groupe ni de ses convois
        if (!moi.estAdministrateur()) {
            if (!"COURTIER".equals(moi.type())) {
                throw new ErreurMetier(CodeErreur.ACCES_REFUSE, null, "Seul le courtier responsable peut créer un convoi");
            }
            if (g.porteParGrossiste() || g.courtierId() != moi.id()) {
                throw new ErreurMetier(CodeErreur.ACCES_REFUSE, null, "Seul le courtier responsable de ce groupe peut créer son convoi");
            }
        }
        int engage = g.quantiteConfirmee() + g.quantiteReservee();
        if (engage < g.quantiteCible() && !"OBJECTIF_ATTEINT".equals(g.statut()) && !"EN_EXPEDITION".equals(g.statut()) && !"LIVRE".equals(g.statut())) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, null,
                    "Ce groupe n'a pas atteint l'objectif (progression inférieure à 100%).");
        }
        if (expeditions.findByGroupeId(d.groupeId()).isPresent()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, null, "Un convoi existe déjà pour ce groupe d'achat");
        }
        if (expeditions.findByReference(d.reference()).isPresent()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, null, "Cette référence de convoi existe déjà");
        }
        Instant maintenant = horloge.instant();
        if (g.ouvert()) {
            groupes.transitionner(d.groupeId(), "OBJECTIF_ATTEINT", moi.estAdministrateur() ? "ADMINISTRATEUR" : "COURTIER");
        }
        Expedition e = new Expedition(d.groupeId(), d.reference().strip(), StatutExpedition.ACHETE, maintenant, d.transporteur());
        e = expeditions.save(e);
        evenements.save(new EvenementLogistique(e.getId(), "CREATION_CONVOI", maintenant, "Origine"));
        informer(e, "le suivi de votre colis est ouvert (convoi " + e.getReference() + ")");
        return versVue(e);
    }

    private void verifierProprieteCourtier(Expedition e, UtilisateurCourant moi) {
        if (moi == null) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, null, "Authentification requise");
        }
        if (moi.estAdministrateur()) {
            return;
        }
        if (!"COURTIER".equals(moi.type())) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, null, "Seul le courtier responsable peut modifier ce convoi");
        }
        GroupeAchatApi.GroupeInfo g = groupes.groupe(e.getGroupeId())
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", e.getGroupeId()));
        if (g.porteParGrossiste() || g.courtierId() != moi.id()) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, null, "Seul le courtier responsable de ce groupe peut modifier ce convoi");
        }
    }

    @Transactional
    public ConvoiVue ajouterEtape(long convoiId, EvenementDemande d, UtilisateurCourant moi) {
        Expedition e = expeditions.findById(convoiId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", convoiId));
        verifierProprieteCourtier(e, moi);
        if (d.statut() == null || d.statut().isBlank() || d.localisation() == null || d.localisation().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "Statut et localisation sont obligatoires");
        }
        Instant maintenant = horloge.instant();
        evenements.save(new EvenementLogistique(e.getId(), d.statut().strip(), maintenant, d.localisation().strip()));
        informer(e, d.statut().strip() + " (" + d.localisation().strip() + ")");
        return versVue(e);
    }

    /** ACHETE -> CHEZ_TRANSITAIRE : les marchandises sont remises au transitaire. */
    @Transactional
    public ConvoiVue remettreAuTransitaire(long convoiId, String localisation, UtilisateurCourant moi) {
        Expedition e = expeditions.findById(convoiId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", convoiId));
        verifierProprieteCourtier(e, moi);
        e.transfererTransitaire();
        evenements.save(new EvenementLogistique(e.getId(), "CHEZ_TRANSITAIRE", horloge.instant(),
                localisation != null && !localisation.isBlank() ? localisation.strip() : "Entrepôt du transitaire"));
        informer(e, "vos marchandises sont remises au transitaire");
        return versVue(e);
    }

    @Transactional
    public ConvoiVue lancerTransit(long convoiId, UtilisateurCourant moi) {
        Expedition e = expeditions.findById(convoiId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", convoiId));
        verifierProprieteCourtier(e, moi);
        e.lancerTransit();
        evenements.save(new EvenementLogistique(e.getId(), "EN_TRANSIT", horloge.instant(), "En route"));
        informer(e, "votre colis est en transit");
        return versVue(e);
    }

    @Transactional
    public ConvoiVue declarerDouane(long convoiId, String localisation, UtilisateurCourant moi) {
        Expedition e = expeditions.findById(convoiId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", convoiId));
        verifierProprieteCourtier(e, moi);
        e.declarerDouane();
        evenements.save(new EvenementLogistique(e.getId(), "BLOQUE_DOUANE", horloge.instant(),
                localisation != null ? localisation : "Poste frontalier / Douane"));
        informer(e, "votre colis est en contrôle douanier");
        return versVue(e);
    }

    /** EN_TRANSIT -> ARRIVE : le convoi est arrivé à destination. */
    @Transactional
    public ConvoiVue marquerArrive(long convoiId, String localisation, UtilisateurCourant moi) {
        Expedition e = expeditions.findById(convoiId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", convoiId));
        verifierProprieteCourtier(e, moi);
        e.marquerArrive();
        evenements.save(new EvenementLogistique(e.getId(), "ARRIVE", horloge.instant(),
                localisation != null && !localisation.isBlank() ? localisation.strip() : "Bamako"));
        informer(e, "votre colis est arrivé à destination");
        return versVue(e);
    }

    /** Chaque étape du convoi est notifiée aux commerçants du groupe, à son grossiste et à son porteur. */
    private void informer(Expedition e, String etape) {
        GroupeAchatApi.GroupeInfo g = groupes.groupe(e.getGroupeId()).orElse(null);
        if (g == null) {
            return;
        }
        String message = "Groupe #" + g.id() + " (" + g.produitNom() + ") : " + etape + ".";
        java.util.Set<Long> destinataires = new java.util.LinkedHashSet<>();
        participations.confirmees(g.id()).forEach(p -> destinataires.add(p.commercantId()));
        destinataires.add(g.grossisteId());
        destinataires.add(g.porteurId());
        destinataires.forEach(id -> notifications.notifier(id, message));
    }

    private ConvoiVue versVue(Expedition e) {
        List<EvenementVue> evts = evenements.findByExpeditionIdOrderByDateAsc(e.getId()).stream()
                .map(ev -> new EvenementVue(ev.getId(), ev.getStatut(), ev.getLocalisation(), ev.getDate()))
                .toList();
        return new ConvoiVue(e.getId(), e.getGroupeId(), e.getReference(), e.getStatut().name(),
                e.getDateDepart(), e.getTransporteur(), evts);
    }
}
