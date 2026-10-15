package ml.dogo.participation.application;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.catalogue.api.CatalogueApi;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.participation.api.Evenements;
import ml.dogo.participation.domain.StatutParticipation;
import ml.dogo.participation.persistence.HistoriqueParticipation;
import ml.dogo.participation.persistence.HistoriqueParticipationRepository;
import ml.dogo.participation.persistence.Participation;
import ml.dogo.participation.persistence.ParticipationRepository;
import ml.dogo.participation.persistence.SnapshotGroupe;
import ml.dogo.participation.persistence.SnapshotGroupeRepository;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.persistence.Verrou;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Rejoindre un groupe, réserver, annuler, expirer (RG-26 à RG-32). */
@Service
public class ParticipationService {

    static final Set<StatutParticipation> ACTIVES = EnumSet.of(StatutParticipation.DEMANDEE,
            StatutParticipation.RESERVEE, StatutParticipation.CONFIRMEE);

    public record ParticipationVue(long id, long groupeId, String produit, String sku, String taille, String couleur,
                                   int quantite, String statut, BigDecimal prixUnitaire, BigDecimal montant,
                                   Instant expirationReservation, Instant dateCreation) {
    }

    public record EtapeVue(String ancien, String nouveau, Instant date) {
    }

    private final ParticipationRepository participations;
    private final SnapshotGroupeRepository snapshots;
    private final HistoriqueParticipationRepository historique;
    private final GroupeAchatApi campagne;
    private final CatalogueApi catalogue;
    private final IdentiteApi identite;
    private final ApplicationEventPublisher evenements;
    private final DogoProperties proprietes;
    private final Clock horloge;
    private final Verrou verrou;

    public ParticipationService(ParticipationRepository participations, SnapshotGroupeRepository snapshots,
                                HistoriqueParticipationRepository historique, GroupeAchatApi campagne,
                                CatalogueApi catalogue, IdentiteApi identite, ApplicationEventPublisher evenements,
                                DogoProperties proprietes, Clock horloge,
                                Verrou verrou) {
        this.participations = participations;
        this.snapshots = snapshots;
        this.historique = historique;
        this.campagne = campagne;
        this.catalogue = catalogue;
        this.identite = identite;
        this.evenements = evenements;
        this.proprietes = proprietes;
        this.horloge = horloge;
        this.verrou = verrou;
    }

    /** RG-26 à RG-29 : réserve les unités (atomique), fige le prix, ouvre le délai de paiement. */
    @Transactional
    public ParticipationVue rejoindre(long commercantId, long groupeId, long varianteId, int quantite) {
        IdentiteApi.ActeurInfo acteur = identite.exigerActif(commercantId);
        if (!"COMMERCANT".equals(acteur.type())) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-26", "Seul un commerçant actif rejoint un groupe");
        }
        GroupeAchatApi.GroupeInfo g = campagne.groupe(groupeId).orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));
        if (!g.ouvert()) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-26", "Seul un groupe ouvert accepte des participations");
        }
        CatalogueApi.VarianteInfo variante = catalogue.variante(varianteId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Variante", varianteId));
        if (variante.produitId() != g.produitId()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-26", "Cette variante n'appartient pas au produit du groupe");
        }
        if (quantite <= 0 || quantite < g.quantiteMinParCommercant()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-27",
                    "La quantité doit être un entier positif d'au moins " + g.quantiteMinParCommercant());
        }
        long plafond = Math.max(g.quantiteMinParCommercant(), (long) Math.ceil(g.quantiteCible() * 0.50));
        if (g.quantiteCible() > 2 && quantite > plafond) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-27",
                    "La quantité demandée (" + quantite + ") dépasse le plafond autorisé de 50% de la cible (" + plafond + ")");
        }
        if (participations.existsByGroupeIdAndCommercantIdAndVarianteIdAndStatutIn(groupeId, commercantId, varianteId, ACTIVES)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-26",
                    "Vous participez déjà à ce groupe avec cette variante : annulez d'abord votre participation");
        }
        campagne.reserver(groupeId, quantite);
        Instant maintenant = horloge.instant();
        Participation p = participations.save(new Participation(groupeId, commercantId, varianteId, quantite,
                maintenant, maintenant.plus(proprietes.reservation().duree())));
        historique.save(new HistoriqueParticipation(p.getId(), null, StatutParticipation.DEMANDEE, maintenant));
        snapshots.save(new SnapshotGroupe(p.getId(), g.produitNom(), g.prixUnitaire(), g.fraisUnitaire(),
                g.quantiteCible(), maintenant));
        transiter(p, StatutParticipation.RESERVEE, maintenant);
        return vue(p);
    }

    /** RG-31 : annulation libre tant que le groupe est ouvert ; une participation payée déclenche un remboursement. */
    @Transactional
    public ParticipationVue annuler(long commercantId, long participationId) {
        Participation p = verrouiller(participationId)
                .filter(x -> x.getCommercantId().equals(commercantId))
                .orElseThrow(() -> ErreurMetier.nonTrouve("Participation", participationId));
        Instant maintenant = horloge.instant();
        StatutParticipation avant = p.getStatut();
        GroupeAchatApi.GroupeInfo g = campagne.groupe(p.getGroupeId()).orElseThrow();
        if (!g.ouvert() || g.quantiteConfirmee() >= g.quantiteCible()) {
            throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-31",
                    "L'annulation et le remboursement ne sont possibles qu'avant l'atteinte des 100% de l'objectif du groupe.");
        }
        switch (avant) {
            case DEMANDEE, RESERVEE -> {
                transiter(p, StatutParticipation.ANNULEE, maintenant);
                campagne.libererReservation(p.getGroupeId(), p.getQuantite());
                evenements.publishEvent(new Evenements.ParticipationAnnulee(p.getId(), p.getGroupeId(),
                        commercantId, p.getQuantite(), false, "ANNULATION_CLIENT"));
            }
            case CONFIRMEE -> {
                // Ordre voulu : l'entité est modifiée d'abord ; la requête atomique qui suit l'enregistre puis vide le contexte.
                transiter(p, StatutParticipation.ANNULEE, maintenant);
                campagne.retirerConfirmation(p.getGroupeId(), p.getQuantite());
                evenements.publishEvent(new Evenements.ParticipationAnnulee(p.getId(), p.getGroupeId(),
                        commercantId, p.getQuantite(), true, "ANNULATION_CLIENT"));
            }
            case ANNULEE -> {
                // Idempotence : la participation est déjà annulée, on retourne simplement sa vue à jour
            }
            default -> throw new ErreurMetier(CodeErreur.TRANSITION_INTERDITE, "RG-31",
                    "Cette participation ne peut plus être annulée (" + avant + ")");
        }
        return vue(p);
    }

    /** RG-30 : le paiement reçu confirme la participation et la quantité du groupe, dans la même transaction. */
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean confirmerApresPaiement(long participationId) {
        Participation p = verrouiller(participationId).orElse(null);
        if (p == null || p.getStatut() != StatutParticipation.RESERVEE) {
            return false;
        }
        if (!campagne.confirmer(p.getGroupeId(), p.getQuantite())) {
            return false;
        }
        // La confirmation du quota a vidé le contexte de persistance : on reprend la participation (déjà verrouillée).
        p = verrouiller(participationId).orElseThrow();
        transiter(p, StatutParticipation.CONFIRMEE, horloge.instant());
        // RG-21 : seulement maintenant que cette participation est confirmée, pour que la création des commandes la voie.
        campagne.verifierObjectif(p.getGroupeId());
        return true;
    }

    /** RG-28 : sans paiement dans le délai, la réservation expire et les unités retournent au groupe. */
    @Transactional
    public void expirer(long participationId) {
        Participation p = verrouiller(participationId).orElse(null);
        Instant maintenant = horloge.instant();
        if (p == null || !(p.getStatut() == StatutParticipation.DEMANDEE || p.getStatut() == StatutParticipation.RESERVEE)
                || p.getDateExpirationReservation() == null || p.getDateExpirationReservation().isAfter(maintenant)) {
            return;
        }
        Evenements.VerificationExpiration question = new Evenements.VerificationExpiration(participationId);
        evenements.publishEvent(question);
        if (question.vetoOppose()) {
            return;
        }
        transiter(p, StatutParticipation.EXPIREE, maintenant);
        campagne.libererReservation(p.getGroupeId(), p.getQuantite());
    }

    /** RG-22 / RG-24 : le groupe est terminé sans succès ; toutes ses participations actives sont annulées. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void annulerToutesDuGroupe(long groupeId, String motif) {
        Instant maintenant = horloge.instant();
        for (Long id : participations.identifiantsDuGroupe(groupeId, ACTIVES)) {
            Participation p = verrouiller(id).orElseThrow();
            if (!p.getStatut().active()) {
                continue;
            }
            boolean payee = p.getStatut() == StatutParticipation.CONFIRMEE;
            transiter(p, StatutParticipation.ANNULEE, maintenant);
            if (!payee) {
                campagne.libererReservation(groupeId, p.getQuantite());
            }
            evenements.publishEvent(new Evenements.ParticipationAnnulee(p.getId(), groupeId, p.getCommercantId(),
                    p.getQuantite(), payee, motif));
        }
    }

    // --------------------------------------------------------------- consultation

    @Transactional(readOnly = true)
    public List<ParticipationVue> mesParticipations(long commercantId) {
        return participations.findByCommercantIdOrderByIdDesc(commercantId).stream().map(this::vue).toList();
    }

    @Transactional(readOnly = true)
    public ParticipationVue detail(long commercantId, long participationId) {
        return vue(chargerPour(commercantId, participationId));
    }

    @Transactional(readOnly = true)
    public List<EtapeVue> historique(long commercantId, long participationId) {
        chargerPour(commercantId, participationId);
        return historique.findByParticipationIdOrderByIdAsc(participationId).stream()
                .map(h -> new EtapeVue(h.getAncienStatut() == null ? null : h.getAncienStatut().name(),
                        h.getNouveauStatut().name(), h.getDateEvenement())).toList();
    }

    // ---------------------------------------------------------------- utilitaires

    /** RG-32 : le changement de statut et sa ligne d'historique sont toujours écrits ensemble. */
    private void transiter(Participation p, StatutParticipation cible, Instant maintenant) {
        StatutParticipation ancien = p.changerStatut(cible);
        historique.save(new HistoriqueParticipation(p.getId(), ancien, cible, maintenant));
    }

    private java.util.Optional<Participation> verrouiller(long participationId) {
        return verrou.ecriture(Participation.class, participationId);
    }

    private Participation chargerPour(long commercantId, long participationId) {
        return participations.findById(participationId).filter(x -> x.getCommercantId().equals(commercantId))
                .orElseThrow(() -> ErreurMetier.nonTrouve("Participation", participationId));
    }

    private ParticipationVue vue(Participation p) {
        SnapshotGroupe s = snapshots.findByParticipationId(p.getId()).orElseThrow();
        CatalogueApi.VarianteInfo v = catalogue.variante(p.getVarianteId()).orElseThrow();
        return new ParticipationVue(p.getId(), p.getGroupeId(), s.getProduitFige(), v.sku(), v.taille(), v.couleur(),
                p.getQuantite(), p.getStatut().name(), s.getPrixFige(),
                s.getPrixFige().multiply(BigDecimal.valueOf(p.getQuantite())), p.getDateExpirationReservation(),
                p.getDateCreation());
    }
}

