package ml.dogo.identite.domain;

/**
 * Fonction d'un administrateur : elle fixe ce qu'il peut faire dans la console (permissions dans
 * {@code AuthService.permissionsAdministratives}). TECHNIQUE est réservé à l'administrateur principal, qui crée les
 * autres administrateurs et leur attribue l'une des fonctions restantes (RG-06).
 */
public enum RoleAdministratif {

    VALIDATION("Validation", "Valide les dossiers KYC des grossistes et courtiers et modère la publication des groupes."),
    FINANCE("Finance", "Suit les séquestres, approuve les remboursements et les retraits de portefeuille."),
    SUPPORT("Support", "Assiste les utilisateurs : consultation des commandes, suspension et réactivation des comptes."),
    LOGISTIQUE("Logistique", "Suit les colis, valide les réceptions au dépôt, gère les points et les retraits."),
    TECHNIQUE("Administrateur principal", "Accès complet à la plateforme ; crée les administrateurs et définit leur fonction.");

    private final String libelle;
    private final String mission;

    RoleAdministratif(String libelle, String mission) {
        this.libelle = libelle;
        this.mission = mission;
    }

    public String libelle() {
        return libelle;
    }

    public String mission() {
        return mission;
    }
}
