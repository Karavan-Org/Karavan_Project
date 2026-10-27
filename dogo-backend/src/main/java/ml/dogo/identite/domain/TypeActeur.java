package ml.dogo.identite.domain;

public enum TypeActeur {
    COMMERCANT, GROSSISTE, COURTIER, ADMINISTRATEUR;

    /** RG-03 : seul un Grossiste ou un Courtier dépose un dossier KYC et attend une validation. Le commerçant est actif dès son OTP. */
    public boolean exigeKyc() {
        return this == GROSSISTE || this == COURTIER;
    }
}
