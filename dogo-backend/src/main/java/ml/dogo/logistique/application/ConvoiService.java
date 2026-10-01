package ml.dogo.logistique.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import ml.dogo.logistique.domain.StatutExpedition;
import ml.dogo.logistique.persistence.EvenementLogistique;
import ml.dogo.logistique.persistence.EvenementLogistiqueRepository;
import ml.dogo.logistique.persistence.Expedition;
import ml.dogo.logistique.persistence.ExpeditionRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
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
    private final Clock horloge;

    public ConvoiService(ExpeditionRepository expeditions, EvenementLogistiqueRepository evenements, Clock horloge) {
        this.expeditions = expeditions;
        this.evenements = evenements;
        this.horloge = horloge;
    }

    @Transactional(readOnly = true)
    public List<ConvoiVue> lister() {
        return expeditions.findAll().stream().map(this::versVue).toList();
    }

    @Transactional(readOnly = true)
    public ConvoiVue detail(long id) {
        return expeditions.findById(id).map(this::versVue)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", id));
    }

    @Transactional
    public ConvoiVue creer(CreationDemande d) {
        if (d.reference() == null || d.reference().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "La référence du convoi est obligatoire");
        }
        if (expeditions.findByReference(d.reference()).isPresent()) {
            throw new ErreurMetier(CodeErreur.CONFLIT, null, "Cette référence de convoi existe déjà");
        }
        Instant maintenant = horloge.instant();
        Expedition e = new Expedition(d.groupeId(), d.reference().strip(), StatutExpedition.ACHETE, maintenant, d.transporteur());
        e = expeditions.save(e);
        evenements.save(new EvenementLogistique(e.getId(), "CREATION_CONVOI", maintenant, "Origine"));
        return versVue(e);
    }

    @Transactional
    public ConvoiVue ajouterEtape(long convoiId, EvenementDemande d) {
        Expedition e = expeditions.findById(convoiId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", convoiId));
        if (d.statut() == null || d.statut().isBlank() || d.localisation() == null || d.localisation().isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "Statut et localisation sont obligatoires");
        }
        Instant maintenant = horloge.instant();
        evenements.save(new EvenementLogistique(e.getId(), d.statut().strip(), maintenant, d.localisation().strip()));
        return versVue(e);
    }

    @Transactional
    public ConvoiVue lancerTransit(long convoiId) {
        Expedition e = expeditions.findById(convoiId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", convoiId));
        e.lancerTransit();
        evenements.save(new EvenementLogistique(e.getId(), "EN_TRANSIT", horloge.instant(), "En route"));
        return versVue(e);
    }

    @Transactional
    public ConvoiVue declarerDouane(long convoiId, String localisation) {
        Expedition e = expeditions.findById(convoiId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Convoi", convoiId));
        e.declarerDouane();
        evenements.save(new EvenementLogistique(e.getId(), "BLOQUE_DOUANE", horloge.instant(),
                localisation != null ? localisation : "Poste frontalier / Douane"));
        return versVue(e);
    }

    private ConvoiVue versVue(Expedition e) {
        List<EvenementVue> evts = evenements.findByExpeditionIdOrderByDateAsc(e.getId()).stream()
                .map(ev -> new EvenementVue(ev.getId(), ev.getStatut(), ev.getLocalisation(), ev.getDate()))
                .toList();
        return new ConvoiVue(e.getId(), e.getGroupeId(), e.getReference(), e.getStatut().name(),
                e.getDateDepart(), e.getTransporteur(), evts);
    }
}
