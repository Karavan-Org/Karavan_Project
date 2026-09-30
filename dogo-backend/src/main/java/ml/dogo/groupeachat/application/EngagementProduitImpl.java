package ml.dogo.groupeachat.application;

import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.groupeachat.persistence.GroupeAchatRepository;
import ml.dogo.catalogue.api.EngagementProduit;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** RG-15 : répond au catalogue sans qu'il connaisse les groupes. */
@Service
public class EngagementProduitImpl implements EngagementProduit {

    private final GroupeAchatRepository groupes;

    public EngagementProduitImpl(GroupeAchatRepository groupes) {
        this.groupes = groupes;
    }

    @Override
    @Transactional(readOnly = true)
    public boolean engageDansGroupeOuvert(long produitId) {
        return groupes.existsByProduitIdAndStatut(produitId, StatutGroupe.OUVERT);
    }
}

