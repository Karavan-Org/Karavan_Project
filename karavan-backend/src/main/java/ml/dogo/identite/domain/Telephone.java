package ml.dogo.identite.domain;

import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

/** Numéros maliens : 8 chiffres, stockés sous la forme « +223XXXXXXXX » pour que l'unicité (RG-01) soit fiable. */
public final class Telephone {

    private Telephone() {
    }

    public static String normaliser(String brut) {
        if (brut != null) {
            String s = brut.replaceAll("[\\s.\\-()]", "");
            if (s.startsWith("+223")) {
                s = s.substring(4);
            } else if (s.startsWith("00223")) {
                s = s.substring(5);
            } else if (s.length() == 11 && s.startsWith("223")) {
                s = s.substring(3);
            }
            if (s.matches("\\d{8}")) {
                return "+223" + s;
            }
        }
        throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-01", "Numéro de téléphone malien invalide");
    }
}
