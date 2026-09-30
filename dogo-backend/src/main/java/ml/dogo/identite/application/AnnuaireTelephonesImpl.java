package ml.dogo.identite.application;

import java.util.Optional;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.notification.api.AnnuaireTelephones;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Fournit au module notification le numéro de téléphone d'un utilisateur. */
@Service
public class AnnuaireTelephonesImpl implements AnnuaireTelephones {

    private final UtilisateurRepository utilisateurs;

    public AnnuaireTelephonesImpl(UtilisateurRepository utilisateurs) {
        this.utilisateurs = utilisateurs;
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<String> telephoneDe(long utilisateurId) {
        return utilisateurs.findById(utilisateurId).map(Utilisateur::getTelephone);
    }
}
