package ml.dogo.identite.application;

import java.time.Duration;
import java.time.Instant;
import ml.dogo.identite.domain.RegleAcces;
import ml.dogo.identite.persistence.CodeOtpRepository;
import ml.dogo.identite.persistence.UtilisateurRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Compteurs d'échecs (PIN, OTP) écrits dans leur propre transaction : ils doivent survivre à l'annulation
 * de l'opération qui vient d'échouer, sinon la limite d'essais ne servirait à rien (RG-02, RG-07).
 */
@Service
public class CompteursAuthentification {

    private final UtilisateurRepository utilisateurs;
    private final CodeOtpRepository otps;

    public CompteursAuthentification(UtilisateurRepository utilisateurs, CodeOtpRepository otps) {
        this.utilisateurs = utilisateurs;
        this.otps = otps;
    }

    /** @return vrai si la tentative a pu être réservée (code encore utilisable). */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean reserverTentativeOtp(long otpId, int max, Instant maintenant) {
        return otps.reserverTentative(otpId, max, maintenant) == 1;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void enregistrerEchecPin(long utilisateurId, int maxEchecs, Duration verrouillage, Instant maintenant) {
        utilisateurs.incrementerEchecsPin(utilisateurId);
        int echecs = utilisateurs.tentativesPin(utilisateurId);
        Instant verrou = RegleAcces.verrouillageApres(echecs, maxEchecs, verrouillage, maintenant);
        if (verrou != null) {
            utilisateurs.verrouiller(utilisateurId, verrou);
        }
    }
}
