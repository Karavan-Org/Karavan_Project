package ml.dogo.groupeachat.application;

import java.time.Clock;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.groupeachat.persistence.ConditionCommerciale;
import ml.dogo.groupeachat.persistence.ConditionCommercialeRepository;
import ml.dogo.groupeachat.persistence.GrilleTarifaire;
import ml.dogo.groupeachat.persistence.GrilleTarifaireRepository;
import ml.dogo.groupeachat.persistence.GroupeAchat;
import ml.dogo.groupeachat.persistence.GroupeAchatRepository;
import ml.dogo.catalogue.api.CatalogueApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Opérations sur les quotas et les états, exposées aux autres modules (RG-21, RG-23, RG-30, RG-31). */
@Service
public class GroupeAchatApiImpl implements GroupeAchatApi {

    private final GroupeAchatRepository groupes;
    private final GrilleTarifaireRepository grilles;
    private final ConditionCommercialeRepository conditions;
    private final CatalogueApi catalogue;
    private final MoteurEtatsGroupe moteur;
    private final Clock horloge;

    public GroupeAchatApiImpl(GroupeAchatRepository groupes, GrilleTarifaireRepository grilles,
                           ConditionCommercialeRepository conditions, CatalogueApi catalogue, MoteurEtatsGroupe moteur,
                           Clock horloge) {
        this.groupes = groupes;
        this.grilles = grilles;
        this.conditions = conditions;
        this.catalogue = catalogue;
        this.moteur = moteur;
        this.horloge = horloge;
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<GroupeInfo> groupe(long groupeId) {
        return groupes.findById(groupeId).map(g -> {
            GrilleTarifaire grille = grilles.findByGroupeId(g.getId()).orElseThrow();
            int min = conditions.findByGroupeId(g.getId()).map(ConditionCommerciale::getQuantiteMinParCommercant).orElse(1);
            String nom = catalogue.produit(g.getProduitId()).map(CatalogueApi.ProduitInfo::nom).orElse("");
            return new GroupeInfo(g.getId(), g.getCourtierId(), g.getGrossisteId(), g.getProduitId(), nom,
                    g.getStatut().name(), g.getQuantiteCible(), g.getQuantiteConfirmee(), g.getQuantiteReservee(),
                    g.getPrixUnitaire(), grille.getFraisPlateforme(), grille.getTauxCommission(), min,
                    g.getDateLimite());
        });
    }

    /** RG-23 : une seule requête conditionnelle ; si elle ne touche aucune ligne, il n'y a plus de place. */
    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void reserver(long groupeId, int quantite) {
        if (groupes.reserver(groupeId, quantite, horloge.instant()) != 1) {
            throw new ErreurMetier(CodeErreur.QUOTA_INSUFFISANT, "RG-23",
                    "Quantité indisponible : le groupe est complet, fermé ou n'est plus ouvert");
        }
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void libererReservation(long groupeId, int quantite) {
        if (groupes.libererReservation(groupeId, quantite) != 1) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-28", "Aucune réservation de cette taille à libérer");
        }
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean confirmer(long groupeId, int quantite) {
        return groupes.confirmer(groupeId, quantite) == 1;
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void verifierObjectif(long groupeId) {
        if (groupes.objectifAtteint(groupeId) > 0
                && groupes.statutDe(groupeId).orElse(null) == StatutGroupe.OUVERT) {
            moteur.transitionner(groupeId, StatutGroupe.OBJECTIF_ATTEINT, "SYSTEME", null);
        }
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void retirerConfirmation(long groupeId, int quantite) {
        if (groupes.retirerConfirmation(groupeId, quantite) != 1) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-31",
                    "Annulation impossible : le groupe n'est plus ouvert");
        }
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void transitionner(long groupeId, String cible, String auteur) {
        moteur.transitionner(groupeId, StatutGroupe.valueOf(cible.toUpperCase(Locale.ROOT)), auteur, null);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Long> groupeIdsParCourtier(long courtierId) {
        return groupes.findByCourtierIdOrderByIdDesc(courtierId).stream()
                .map(GroupeAchat::getId).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<Long> groupeIdsParGrossiste(long grossisteId) {
        return groupes.findByGrossisteIdOrderByIdDesc(grossisteId).stream()
                .map(GroupeAchat::getId).toList();
    }
}

