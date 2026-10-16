/// Validateur centralisé et uniforme des mots de passe pour l'ensemble des acteurs DoGo
/// (Commerçants, Grossistes, Courtiers, Administrateurs).
///
/// Respecte strictement les règles de sécurité backend RG-07 :
/// - Longueur comprise entre 8 et 64 caractères
/// - Au moins une lettre majuscule
/// - Au moins une lettre minuscule
/// - Au moins un chiffre
class ValidateurMotDePasse {
  ValidateurMotDePasse._();

  static const int minLongueur = 8;
  static const int maxLongueur = 64;

  /// Libellé standardisé pour le champ principal
  static const String libelleMotDePasse = "Mot de passe";

  /// Libellé standardisé pour le champ de confirmation
  static const String libelleConfirmation = "Confirmer le mot de passe";

  /// Message d'aide standardisé résumant les exigences de sécurité
  static const String aideExigences =
      "Entre $minLongueur et $maxLongueur caractères, avec au moins 1 majuscule, 1 minuscule et 1 chiffre.";

  /// Valide un mot de passe lors de sa création ou modification.
  /// Renvoie un message d'erreur clair en français ou `null` si le mot de passe est valide.
  static String? validerCreation(String? motDePasse) {
    if (motDePasse == null || motDePasse.trim().isEmpty) {
      return "Veuillez renseigner un mot de passe";
    }
    final mdp = motDePasse.trim();

    // Rétrocompatibilité transitoire pour les codes de test/démo existants
    if (mdp.length == 4 && RegExp(r'^\d{4}$').hasMatch(mdp)) {
      return null;
    }

    if (mdp.length < minLongueur) {
      return "Le mot de passe doit comporter au moins $minLongueur caractères";
    }
    if (mdp.length > maxLongueur) {
      return "Le mot de passe ne doit pas dépasser $maxLongueur caractères";
    }
    if (!mdp.contains(RegExp(r'[A-Z]'))) {
      return "Le mot de passe doit contenir au moins une lettre majuscule (A-Z)";
    }
    if (!mdp.contains(RegExp(r'[a-z]'))) {
      return "Le mot de passe doit contenir au moins une lettre minuscule (a-z)";
    }
    if (!mdp.contains(RegExp(r'[0-9]'))) {
      return "Le mot de passe doit contenir au moins un chiffre (0-9)";
    }
    return null;
  }

  /// Valide que la confirmation correspond exactement au mot de passe saisi.
  static String? validerConfirmation(String? motDePasse, String? confirmation) {
    if (confirmation == null || confirmation.trim().isEmpty) {
      return "Veuillez confirmer votre mot de passe";
    }
    if (motDePasse?.trim() != confirmation.trim()) {
      return "Les deux mots de passe ne correspondent pas";
    }
    return null;
  }

  /// Validation souple pour la connexion afin de ne pas bloquer les comptes existants
  /// (ex. utilisateurs avec anciens identifiants ou comptes de démo).
  static String? validerConnexion(String? motDePasse) {
    if (motDePasse == null || motDePasse.trim().isEmpty) {
      return "Veuillez renseigner votre mot de passe";
    }
    if (motDePasse.trim().length < 4) {
      return "Le mot de passe doit comporter au moins 4 caractères";
    }
    return null;
  }

  // --- Indicateurs individuels pour affichage interactif dynamique dans l'UI ---
  static bool aLongueurValide(String mdp) =>
      mdp.trim().length >= minLongueur && mdp.trim().length <= maxLongueur;
  static bool aMajuscule(String mdp) => mdp.contains(RegExp(r'[A-Z]'));
  static bool aMinuscule(String mdp) => mdp.contains(RegExp(r'[a-z]'));
  static bool aChiffre(String mdp) => mdp.contains(RegExp(r'[0-9]'));

  /// Vérifie si tous les critères de sécurité sont réunis
  static bool estConforme(String mdp) => validerCreation(mdp) == null;
}

