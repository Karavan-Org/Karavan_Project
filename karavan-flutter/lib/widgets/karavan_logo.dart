import 'package:flutter/material.dart';

/// Emblème officiel Karavan : la silhouette nomade sur sa dune, main tendue
/// vers trois étoiles dorées, présentée en pastille crème arrondie (lisible en
/// thème clair comme sombre).
class KaravanLogo extends StatelessWidget {
  final double taille;

  const KaravanLogo({super.key, this.taille = 96});

  static const String asset = 'assets/images/logo_karavan.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: taille, height: taille, fit: BoxFit.contain);
  }
}
