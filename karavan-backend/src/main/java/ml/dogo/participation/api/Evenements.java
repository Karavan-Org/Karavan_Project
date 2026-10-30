package ml.dogo.participation.api;

/** Événements publiés par le module participation (synchrones, dans la transaction de l'opération). */
public final class Evenements {

    private Evenements() {
    }

    /**
     * Une participation est annulée. {@code payee} vaut vrai si elle était CONFIRMEE (donc payée) : le module finance
     * rembourse alors ; sinon il abandonne un éventuel paiement en cours. {@code motif} : ANNULATION_CLIENT ou ECHEC_GROUPE.
     */
    public record ParticipationAnnulee(long participationId, long groupeId, long commercantId, int quantite,
                                       boolean payee, String motif) {
    }

    /**
     * Question posée avant d'expirer une réservation : un écouteur (finance) peut opposer son veto tant qu'un paiement
     * est en cours, pour ne pas libérer des unités qui vont être payées.
     */
    public static final class VerificationExpiration {

        private final long participationId;
        private boolean veto;

        public VerificationExpiration(long participationId) {
            this.participationId = participationId;
        }

        public long participationId() {
            return participationId;
        }

        public void opposerVeto() {
            this.veto = true;
        }

        public boolean vetoOppose() {
            return veto;
        }
    }
}
