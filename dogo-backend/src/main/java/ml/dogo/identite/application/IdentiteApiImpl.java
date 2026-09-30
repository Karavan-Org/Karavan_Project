package ml.dogo.identite.application;

import java.util.List;
import java.util.Optional;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.MoyenPaiementRepository;
import ml.dogo.identite.persistence.MoyenPaiementUtilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class IdentiteApiImpl implements IdentiteApi {

    private final UtilisateurRepository utilisateurs;
    private final MoyenPaiementRepository moyens;

    public IdentiteApiImpl(UtilisateurRepository utilisateurs, MoyenPaiementRepository moyens) {
        this.utilisateurs = utilisateurs;
        this.moyens = moyens;
    }

    @Override
    public Optional<ActeurInfo> acteur(long utilisateurId) {
        return utilisateurs.findById(utilisateurId).map(u -> new ActeurInfo(u.getId(), u.typeActeur().name(),
                u.getStatutCompte().name(), u.getNom(), u.getTelephone()));
    }

    @Override
    public MoyenPaiementInfo moyenPaiementDe(long utilisateurId, long moyenId) {
        return moyens.findByIdAndUtilisateurId(moyenId, utilisateurId).map(IdentiteApiImpl::info)
                .orElseThrow(() -> new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-10",
                        "Ce moyen de paiement n'appartient pas à l'utilisateur"));
    }

    @Override
    public Optional<MoyenPaiementInfo> moyenParDefaut(long utilisateurId) {
        return moyens.findFirstByUtilisateurIdAndParDefautTrue(utilisateurId).map(IdentiteApiImpl::info);
    }

    @Override
    public Optional<String> roleAdministratif(long utilisateurId) {
        return utilisateurs.findById(utilisateurId).filter(u -> u instanceof Administrateur)
                .map(u -> ((Administrateur) u).getRoleAdministratif().name());
    }

    @Override
    public List<Long> administrateursActifs() {
        return utilisateurs.identifiantsAdministrateursActifs();
    }

    private static MoyenPaiementInfo info(MoyenPaiementUtilisateur m) {
        return new MoyenPaiementInfo(m.getId(), m.getUtilisateurId(), m.getNumeroMobileMoney(), m.getOperateur().name());
    }
}
