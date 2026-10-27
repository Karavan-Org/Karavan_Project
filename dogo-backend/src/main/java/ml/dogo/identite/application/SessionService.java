package ml.dogo.identite.application;

import java.time.Clock;
import java.time.Instant;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.persistence.SessionUtilisateur;
import ml.dogo.identite.persistence.SessionUtilisateurRepository;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.security.EtatSession;
import ml.dogo.shared.security.VerificateurSession;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Validité des sessions (RG-08) : refuse les sessions invalidées, expirées ou dont le compte est suspendu (RG-09). */
@Service
public class SessionService implements VerificateurSession {

    private final SessionUtilisateurRepository sessions;
    private final UtilisateurRepository utilisateurs;
    private final DogoProperties proprietes;
    private final Clock horloge;

    public SessionService(SessionUtilisateurRepository sessions, UtilisateurRepository utilisateurs,
                          DogoProperties proprietes, Clock horloge) {
        this.sessions = sessions;
        this.utilisateurs = utilisateurs;
        this.proprietes = proprietes;
        this.horloge = horloge;
    }

    @Override
    @Transactional
    public EtatSession verifierEtProlonger(long sessionId, long utilisateurId) {
        Instant maintenant = horloge.instant();
        SessionUtilisateur session = sessions.findById(sessionId).orElse(null);
        if (session == null || !session.getUtilisateurId().equals(utilisateurId) || !session.estValide(maintenant)) {
            return EtatSession.INVALIDE;
        }
        // Le statut est relu à chaque requête : une validation, une suspension ou un rejet s'applique immédiatement
        StatutCompte statut = utilisateurs.statutDe(utilisateurId).orElse(null);
        if (statut == null || !statut.peutSAuthentifier()) {
            return EtatSession.INVALIDE;
        }
        session.prolonger(maintenant, maintenant.plus(proprietes.session().inactivite()));
        return statut == StatutCompte.EN_ATTENTE ? EtatSession.EN_ATTENTE : EtatSession.ACTIF;
    }

    @Transactional
    public void invalider(long sessionId) {
        sessions.findById(sessionId).ifPresent(SessionUtilisateur::invalider);
    }

    @Transactional
    public void invaliderToutes(long utilisateurId) {
        sessions.invaliderToutes(utilisateurId);
    }

    /** Nettoyage quotidien des sessions terminées depuis plus de 90 jours. */
    @Scheduled(cron = "0 30 3 * * *")
    @Transactional
    public void purger() {
        sessions.purger(horloge.instant().minus(java.time.Duration.ofDays(90)));
    }
}
