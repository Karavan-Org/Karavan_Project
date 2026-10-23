// Formats d'affichage partagés : un même montant ou une même date s'affiche partout de la même façon.

/// 1250000 → « 1 250 000 FCFA » (espace insécable fine entre les milliers)
String formaterFcfa(num montant, {bool avecDevise = true}) {
  final entier = montant.round().abs().toString();
  final groupes = <String>[];
  for (var i = entier.length; i > 0; i -= 3) {
    groupes.insert(0, entier.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  final signe = montant < 0 ? '-' : '';
  return '$signe${groupes.join(' ')}${avecDevise ? ' FCFA' : ''}';
}

/// « à l'instant », « il y a 5 min », « il y a 3 h », « hier », « il y a 4 j », puis la date (jj/mm/aaaa)
String dateRelative(DateTime? date, {DateTime? maintenant}) {
  if (date == null) return '';
  final d = date.toLocal();
  final now = maintenant ?? DateTime.now();
  final ecart = now.difference(d);
  if (ecart.isNegative || ecart.inMinutes < 1) return "à l'instant";
  if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
  if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
  if (ecart.inDays == 1) return 'hier';
  if (ecart.inDays < 7) return 'il y a ${ecart.inDays} j';
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${deux(d.day)}/${deux(d.month)}/${d.year}';
}
