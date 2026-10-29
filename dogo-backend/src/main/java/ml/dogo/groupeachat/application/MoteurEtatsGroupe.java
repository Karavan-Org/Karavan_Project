package ml.dogo.groupeachat.application;

import java.time.Clock;
import ml.dogo.groupeachat.api.Evenements;
import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.groupeachat.persistence.GroupeAchatRepository;
import ml.dogo.groupeachat.persistence.TransitionStatutGroupe;
import ml.dogo.groupeachat.persistence.TransitionStatutGroupeRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Seul point de passage des changements d'état d'un groupe (RG-19) : refuse toute transition non autorisée, écrit la
 * trace, puis publie l'événement correspondant. Le changement de statut est une mise à jour conditionnelle : si deux
 * transactions tentent de faire évoluer le même groupe, une seule réussit.
 */
@Service
public class MoteurEtatsGroupe {

    private final GroupeAchatRepository groupes;
    private final TransitionStatutGroupeRepository transitions;
    private final ApplicationEventPublisher evenements;
    private final Clock horloge;

    public MoteurEtatsGroupe(GroupeAchatRepository groupes, TransitionStatutGroupeRepository transitions,
                             ApplicationEventPublisher evenements, Clock horloge) {
        this.groupes = groupes;
        this.transitions = transitions;
        this.evenements = evenements;
        this.horloge = horloge;
    }

    /** À appeler dans la transaction de l'opération métier : la transition et ses conséquences réussissent ou échouent ensemble. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void transitionner(long groupeId, StatutGroupe cible, String auteur, String motif) {
        StatutGroupe ancien = groupes.statutDe(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        ancien.verifierTransition(cible, "RG-19");
        if (groupes.changerStatut(groupeId, ancien.name(), cible.name()) != 1) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-19", "Le groupe vient de changer d'état, réessayez");
        }
        transitions.save(new TransitionStatutGroupe(groupeId, ancien, cible, horloge.instant(), auteur));
        switch (cible) {
            case OBJECTIF_ATTEINT -> evenements.publishEvent(new Evenements.ObjectifAtteint(groupeId));
            case ECHOUE -> evenements.publishEvent(new Evenements.GroupeEchoue(groupeId));
            case ANNULE -> evenements.publishEvent(new Evenements.GroupeAnnule(groupeId, motif));
            default -> {
                // pas d'événement pour les autres états
            }
        }
    }
}

