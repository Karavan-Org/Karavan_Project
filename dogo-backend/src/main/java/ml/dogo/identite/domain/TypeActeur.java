package ml.dogo.identite.domain;

public enum TypeActeur {
    COMMERCANT, GROSSISTE, COURTIER, ADMINISTRATEUR;

    /** RG-03 : un Commerçant est actif dès la vérification de l'OTP, les autres attendent la validation KYC. */
    public boolean exigeKyc() {
        return this == GROSSISTE || this == COURTIER;
    }
}
