package ml.dogo.participation.application;

import ml.dogo.groupeachat.api.Evenements;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/** Réaction du module participation à la fin d'un groupe (RG-22, RG-24). Exécuté dans la transaction qui a changé l'état. */
@Component
public class EcouteursGroupe {

    private final ParticipationService participations;

    public EcouteursGroupe(ParticipationService participations) {
        this.participations = participations;
    }

    @EventListener
    public void groupeEchoue(Evenements.GroupeEchoue e) {
        participations.annulerToutesDuGroupe(e.groupeId(), "ECHEC_GROUPE");
    }

    @EventListener
    public void groupeAnnule(Evenements.GroupeAnnule e) {
        participations.annulerToutesDuGroupe(e.groupeId(), "ECHEC_GROUPE");
    }
}

