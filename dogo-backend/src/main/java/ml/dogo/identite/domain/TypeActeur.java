package ml.dogo.identite.domain;

public enum TypeActeur {
    COMMERCANT, GROSSISTE, COURTIER, ADMINISTRATEUR;

    /** RG-03 : Commerçant, Grossiste et Courtier fournissent leurs documents KYC pour la validation. */
    public boolean exigeKyc() {
        return this == GROSSISTE || this == COURTIER || this == COMMERCANT;
    }
}
