package ml.dogo.shared.security;

/** Implémenté par le module identité : vérifie qu'une session est valide et la prolonge (RG-08, RG-09). */
public interface VerificateurSession {

    boolean verifierEtProlonger(long sessionId, long utilisateurId);
}
