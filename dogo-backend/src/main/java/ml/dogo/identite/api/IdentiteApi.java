package ml.dogo.identite.api;

import java.util.Optional;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

/** Ce que les autres modules ont le droit de savoir sur les utilisateurs. */
public interface IdentiteApi {

    record ActeurInfo(long id, String type, String statut, String nom, String telephone) {

        public boolean actif() {
            return "ACTIF".equals(statut);
        }
    }

    record MoyenPaiementInfo(long id, long utilisateurId, String numero, String operateur) {
    }

    record SupervisionStats(long commercants, long grossistes, long courtiers, long administrateurs) {
        public long totalActeurs() {
            return commercants + grossistes + courtiers;
        }
    }

    SupervisionStats statistiquesSupervision();

    Optional<ActeurInfo> acteur(long utilisateurId);

    /** Renvoie le moyen de paiement s'il appartient bien à l'utilisateur, sinon lève une erreur métier. */
    MoyenPaiementInfo moyenPaiementDe(long utilisateurId, long moyenId);

    /** Moyen par défaut de l'utilisateur (RG-10), ou vide. */
    Optional<MoyenPaiementInfo> moyenParDefaut(long utilisateurId);

    /** Rôle administratif (VALIDATION, FINANCE...) d'un administrateur, ou vide si ce n'est pas un administrateur. */
    Optional<String> roleAdministratif(long utilisateurId);

    /** Identifiants des administrateurs actifs (destinataires des alertes de la plateforme). */
    java.util.List<Long> administrateursActifs();

    /** Renvoie l'acteur s'il existe et si son compte est actif (RG-03, RG-09), sinon lève une erreur métier. */
    default ActeurInfo exigerActif(long utilisateurId) {
        ActeurInfo a = acteur(utilisateurId).orElseThrow(() -> ErreurMetier.nonTrouve("Utilisateur", utilisateurId));
        if (!a.actif()) {
            throw new ErreurMetier(CodeErreur.COMPTE_INACTIF, "RG-09", "Le compte n'est pas actif");
        }
        return a;
    }
}
