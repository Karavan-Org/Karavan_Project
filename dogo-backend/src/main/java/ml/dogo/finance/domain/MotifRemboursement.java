package ml.dogo.finance.domain;

/** Motifs de remboursement (RG-57) et mode d'approbation (RG-60). */
public enum MotifRemboursement {
    ANNULATION_CLIENT(false),
    ECHEC_GROUPE(true),
    ECHEC_FOURNISSEUR(true),
    COLIS_PERDU(false),
    LITIGE_RESOLU(false);

    private final boolean automatique;

    MotifRemboursement(boolean automatique) {
        this.automatique = automatique;
    }

    /** Vrai si le remboursement est approuvé sans intervention d'un administrateur FINANCE. */
    public boolean automatique() {
        return automatique;
    }
}
