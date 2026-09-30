package ml.dogo.logistique.application;

import ml.dogo.logistique.persistence.CodeRetraitRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Compteur d'échecs du code de retrait, écrit dans sa propre transaction : il doit survivre à l'annulation de la
 * tentative qui vient d'échouer, sinon la limite d'essais ne servirait à rien (RG-54). L'appelant ne verrouille jamais
 * la ligne du code (il ne verrouille que les commandes), donc les deux transactions ne s'attendent pas.
 */
@Service
public class CompteursRetrait {

    private final CodeRetraitRepository codes;

    public CompteursRetrait(CodeRetraitRepository codes) {
        this.codes = codes;
    }

    /** @return le nombre d'échecs après cette tentative (le code est bloqué s'il atteint le maximum). */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int enregistrerEchec(long codeId, int maxTentatives) {
        codes.enregistrerEchec(codeId, maxTentatives);
        return codes.tentatives(codeId);
    }
}
