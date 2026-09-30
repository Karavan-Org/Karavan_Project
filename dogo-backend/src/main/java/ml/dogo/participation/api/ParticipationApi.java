package ml.dogo.participation.api;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

/** Ce que les autres modules ont le droit de savoir et de faire sur les participations. */
public interface ParticipationApi {

    record ParticipationInfo(long id, long groupeId, long commercantId, long varianteId, int quantite, String statut,
                             BigDecimal prixUnitaireFige, BigDecimal fraisUnitaireFige, Instant expirationReservation) {

        /** Montant dû : le prix du snapshot, jamais le prix courant du groupe (RG-29, RG-33). */
        public BigDecimal montant() {
            return prixUnitaireFige.multiply(BigDecimal.valueOf(quantite));
        }
    }

    Optional<ParticipationInfo> participation(long participationId);

    /** Participations CONFIRMEE d'un groupe (base des commandes, RG-44). */
    List<ParticipationInfo> confirmees(long groupeId);

    /**
     * RG-30 : à réception du paiement, passe la participation à CONFIRMEE et confirme la quantité dans le groupe, dans
     * la transaction de l'appelant. Renvoie faux si ce n'est plus possible (réservation expirée ou annulée, groupe fermé) :
     * le paiement doit alors être remboursé.
     */
    boolean confirmerApresPaiement(long participationId);
}
