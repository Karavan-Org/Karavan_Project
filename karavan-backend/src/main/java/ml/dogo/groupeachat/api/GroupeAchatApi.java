package ml.dogo.groupeachat.api;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

/** Ce que les autres modules ont le droit de faire avec les groupes d'achat. */
public interface GroupeAchatApi {

    /** {@code courtierId} est nul pour un groupe porté par le grossiste du produit : voir {@link #porteurId()}. */
    record GroupeInfo(long id, Long courtierId, long grossisteId, long produitId, String produitNom, String statut,
                      int quantiteCible, int quantiteConfirmee, int quantiteReservee, BigDecimal prixUnitaire,
                      BigDecimal fraisUnitaire, BigDecimal tauxCommission, int quantiteMinParCommercant,
                      Instant dateLimite) {

        /** Celui qui pilote le groupe et tient le séquestre : le courtier, ou à défaut le grossiste. */
        public long porteurId() {
            return courtierId != null ? courtierId : grossisteId;
        }

        public boolean porteParGrossiste() {
            return courtierId == null;
        }

        public boolean ouvert() {
            return "OUVERT".equals(statut);
        }
    }

    Optional<GroupeInfo> groupe(long groupeId);

    /** RG-23 : réserve des unités de façon atomique ; lève QUOTA_INSUFFISANT si le groupe n'a plus la place ou n'est pas ouvert. */
    void reserver(long groupeId, int quantite);

    /** Rend des unités réservées au groupe (RG-28). */
    void libererReservation(long groupeId, int quantite);

    /**
     * RG-30 : transforme des unités réservées en unités confirmées. Renvoie faux si le groupe n'est plus ouvert
     * (le paiement doit alors être remboursé). N'évalue pas l'objectif : l'appelant confirme d'abord sa participation,
     * puis appelle {@link #verifierObjectif}, pour que les écouteurs voient toutes les participations confirmées.
     */
    boolean confirmer(long groupeId, int quantite);

    /** RG-21 : si la quantité confirmée atteint la cible, le groupe passe à OBJECTIF_ATTEINT (événement publié). */
    void verifierObjectif(long groupeId);

    /** RG-31 : retire des unités confirmées (annulation avant l'objectif). */
    void retirerConfirmation(long groupeId, int quantite);

    /** Passage d'état demandé par la logistique (EN_EXPEDITION, LIVRE, TERMINE), toujours validé par le moteur d'états. */
    void transitionner(long groupeId, String cible, String auteur);

    /** Renvoie les identifiants de groupes gérés par un courtier donné. */
    List<Long> groupeIdsParCourtier(long courtierId);

    /** Renvoie les identifiants de groupes montés sur les produits d'un grossiste donné. */
    List<Long> groupeIdsParGrossiste(long grossisteId);
}

