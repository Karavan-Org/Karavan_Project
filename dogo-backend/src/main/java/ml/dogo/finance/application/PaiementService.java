package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import ml.dogo.finance.domain.StatutPaiement;
import ml.dogo.finance.persistence.Paiement;
import ml.dogo.finance.persistence.PaiementRepository;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.participation.api.ParticipationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import ml.dogo.shared.persistence.Verrou;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Initiation d'un paiement Mobile Money (RG-33, RG-34) et expiration des paiements sans réponse. */
@Service
public class PaiementService {

    /** Au-delà, un paiement sans callback est considéré comme abandonné. */
    static final Duration DELAI_REPONSE_OPERATEUR = Duration.ofMinutes(10);

    public record PaiementVue(long id, long participationId, BigDecimal montant, BigDecimal montantRembourse,
                              String statut, Instant dateInitiation) {
    }

    private final PaiementRepository paiements;
    private final ParticipationApi participations;
    private final IdentiteApi identite;
    private final PasserelleMobileMoney passerelle;
    private final Verrou verrou;
    private final Clock horloge;

    public PaiementService(PaiementRepository paiements, ParticipationApi participations, IdentiteApi identite,
                           PasserelleMobileMoney passerelle, Verrou verrou, Clock horloge) {
        this.paiements = paiements;
        this.participations = participations;
        this.identite = identite;
        this.passerelle = passerelle;
        this.verrou = verrou;
        this.horloge = horloge;
    }

    /**
     * RG-33 : paiement d'une participation RESERVEE, au montant du snapshot, avec un moyen du Commerçant.
     * RG-34 : la même clé d'idempotence renvoie le paiement déjà créé, sans nouveau débit.
     */
    @Transactional
    public PaiementVue initier(long commercantId, long participationId, Long moyenId, String cleIdempotence) {
        if (cleIdempotence == null || cleIdempotence.isBlank() || cleIdempotence.length() > 80) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-34",
                    "La clé d'idempotence est obligatoire (80 caractères maximum)");
        }
        ParticipationApi.ParticipationInfo part = participations.participation(participationId)
                .filter(x -> x.commercantId() == commercantId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Participation", participationId));
        var existant = paiements.findByCleIdempotence(cleIdempotence);
        if (existant.isPresent()) {
            if (existant.get().getParticipationId() != participationId) {
                throw new ErreurMetier(CodeErreur.CONFLIT, "RG-34", "Cette clé d'idempotence est déjà utilisée");
            }
            return vue(existant.get());
        }
        if (!"RESERVEE".equals(part.statut())) {
            throw new ErreurMetier(CodeErreur.PAIEMENT_INVALIDE, "RG-33", "Seule une participation réservée peut être payée");
        }
        Instant maintenant = horloge.instant();
        if (part.expirationReservation() != null && !maintenant.isBefore(part.expirationReservation())) {
            throw new ErreurMetier(CodeErreur.PAIEMENT_INVALIDE, "RG-28", "La réservation a expiré");
        }
        if (paiements.existeVivant(participationId)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-34", "Un paiement est déjà en cours ou effectué pour cette participation");
        }
        IdentiteApi.MoyenPaiementInfo moyen = moyenId != null
                ? identite.moyenPaiementDe(commercantId, moyenId)
                : identite.moyenParDefaut(commercantId).orElseThrow(() -> new ErreurMetier(CodeErreur.DONNEES_INVALIDES,
                        "RG-10", "Aucun moyen de paiement : ajoutez un numéro Mobile Money"));
        Paiement p = paiements.saveAndFlush(new Paiement(participationId, moyen.id(), part.montant(), cleIdempotence, maintenant));
        passerelle.demanderDebit("DOGO-" + p.getId(), moyen.numero(), moyen.operateur(), p.getMontant());
        p.changerStatut(StatutPaiement.EN_ATTENTE, maintenant);
        return vue(p);
    }

    @Transactional(readOnly = true)
    public List<PaiementVue> deLaParticipation(long commercantId, long participationId) {
        participations.participation(participationId).filter(x -> x.commercantId() == commercantId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Participation", participationId));
        return paiements.findByParticipationIdOrderByIdDesc(participationId).stream().map(PaiementService::vue).toList();
    }

    /** Abandonne un paiement resté sans réponse de l'opérateur ; appelée par le planificateur. */
    @Transactional
    public void expirer(long paiementId) {
        Paiement p = verrou.ecriture(Paiement.class, paiementId).orElse(null);
        Instant maintenant = horloge.instant();
        if (p == null || !(p.getStatut() == StatutPaiement.INITIE || p.getStatut() == StatutPaiement.EN_ATTENTE)
                || p.getDateInitiation().plus(DELAI_REPONSE_OPERATEUR).isAfter(maintenant)) {
            return;
        }
        p.changerStatut(StatutPaiement.EXPIRE, maintenant);
    }

    private static PaiementVue vue(Paiement p) {
        return new PaiementVue(p.getId(), p.getParticipationId(), p.getMontant(), p.getMontantRembourse(),
                p.getStatut().name(), p.getDateInitiation());
    }
}
