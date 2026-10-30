package ml.dogo.finance.domain;

import java.math.BigDecimal;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

/** Règles financières pures : remboursement (RG-58), libération (RG-38), retrait (RG-41). */
public final class RegleFinance {

    private RegleFinance() {
    }

    /** RG-58 : le total remboursé ne dépasse jamais le montant payé. */
    public static void verifierMontantRemboursable(BigDecimal paye, BigDecimal dejaRembourse, BigDecimal demande) {
        if (demande == null || demande.signum() <= 0) {
            throw new ErreurMetier(CodeErreur.REMBOURSEMENT_INVALIDE, "RG-58", "Le montant à rembourser doit être positif");
        }
        if (dejaRembourse.add(demande).compareTo(paye) > 0) {
            throw new ErreurMetier(CodeErreur.REMBOURSEMENT_INVALIDE, "RG-58",
                    "Le total remboursé dépasserait le montant payé");
        }
    }

    /** RG-38 : part reversée au Courtier = montant bloqué - frais de plateforme. */
    public static BigDecimal partCourtier(BigDecimal montantBloque, BigDecimal frais) {
        if (frais.signum() < 0 || frais.compareTo(montantBloque) > 0) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-37", "Frais de plateforme incohérents");
        }
        return montantBloque.subtract(frais);
    }

    /** RG-41 : seul le solde disponible peut être retiré. */
    public static void verifierRetrait(BigDecimal soldeDisponible, BigDecimal demande) {
        if (demande == null || demande.signum() <= 0) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-41", "Le montant à retirer doit être positif");
        }
        if (demande.compareTo(soldeDisponible) > 0) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-41", "Solde disponible insuffisant");
        }
    }
}
