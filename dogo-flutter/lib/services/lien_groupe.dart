/// Lien d'invitation vers un groupe d'achat : le créateur le partage, le commerçant l'ouvre
/// (lien cliquable, ou collé dans l'app) pour rejoindre le groupe.
class LienGroupe {
  LienGroupe._();

  /// Base des liens partagés (surchargeable : --dart-define=lienGroupe=https://mon-domaine/groupe/).
  /// L'app Android déclare ce domaine et le schéma dogo:// pour s'ouvrir directement sur le groupe.
  static const String base = String.fromEnvironment('lienGroupe', defaultValue: 'https://dogo.ml/groupe/');

  /// Groupe à ouvrir dès qu'un commerçant sera connecté (lien reçu avant la connexion)
  static int? enAttente;

  static String lien(int groupeId) => '$base$groupeId';

  static String code(int groupeId) => 'DOGO-$groupeId';

  static String message({required int groupeId, required String titre, num? prixUnitaire}) {
    final prix = (prixUnitaire != null && prixUnitaire > 0) ? " à $prixUnitaire FCFA la pièce" : "";
    return "Rejoignez mon groupe d'achat « $titre »$prix sur dɔgɔ : ${lien(groupeId)}\n"
        "(ou saisissez le code ${code(groupeId)} dans l'app)";
  }

  /// Retrouve l'identifiant du groupe dans un lien (https://…/groupe/12, dogo://groupe/12, /groupe/12),
  /// un code (DOGO-12) ou un simple numéro.
  static int? extraireId(String? texte) {
    if (texte == null) return null;
    final t = texte.trim();
    final motif = RegExp(r'groupe/(\d+)', caseSensitive: false).firstMatch(t) ??
        RegExp(r'dogo-(\d+)', caseSensitive: false).firstMatch(t) ??
        RegExp(r'^#?(\d+)$').firstMatch(t);
    return motif == null ? null : int.tryParse(motif.group(1)!);
  }
}
