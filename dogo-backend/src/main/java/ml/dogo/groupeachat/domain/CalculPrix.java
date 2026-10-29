package ml.dogo.groupeachat.domain;

import java.math.BigDecimal;
import java.math.RoundingMode;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

/** Calculs de prix en XOF (RG-20, RG-37, RG-42). Aucune dépendance technique. */
public final class CalculPrix {

    private CalculPrix() {
    }

    /** Composantes d'un prix unitaire. */
    public record Composantes(BigDecimal marchandise, BigDecimal transport, BigDecimal fraisPlateforme,
                              BigDecimal douane, BigDecimal autres) {
        public Composantes {
            for (BigDecimal v : new BigDecimal[]{marchandise, transport, fraisPlateforme, douane, autres}) {
                if (v == null || v.signum() < 0) {
                    throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-17",
                            "Toutes les composantes du prix doivent être renseignées et positives");
                }
            }
            if (marchandise.signum() == 0) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-17", "Le prix de la marchandise est obligatoire");
            }
        }
    }

    /** RG-37 : frais de plateforme = taux x prix de la marchandise (arrondi au franc). */
    public static BigDecimal fraisPlateforme(BigDecimal prixMarchandise, BigDecimal taux) {
        return prixMarchandise.multiply(taux).setScale(0, RoundingMode.HALF_UP);
    }

    /** RG-20 : prix unitaire = marchandise + transport + frais plateforme + douane + autres. */
    public static BigDecimal totalUnitaire(Composantes c) {
        return c.marchandise().add(c.transport()).add(c.fraisPlateforme()).add(c.douane()).add(c.autres());
    }

    /** Montant dû pour une quantité, sur la base du prix figé. */
    public static BigDecimal montant(BigDecimal prixUnitaire, int quantite) {
        if (quantite <= 0) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-27", "La quantité doit être positive");
        }
        return prixUnitaire.multiply(BigDecimal.valueOf(quantite));
    }

    /** RG-42 : conversion d'un montant en devise étrangère vers XOF avec le taux figé. */
    public static BigDecimal convertirEnXof(BigDecimal montantDevise, BigDecimal taux) {
        return montantDevise.multiply(taux).setScale(0, RoundingMode.HALF_UP);
    }
}

