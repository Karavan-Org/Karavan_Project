import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../widgets/didacticiel_guide_overlay.dart';

/// Didacticiel interactif guidé pour la première connexion du Grossiste.
/// Délègue au composant universel [DidacticielGuideOverlay] configuré pour [RoleActeur.grossiste].
class DidacticielGrossisteGuide extends StatelessWidget {
  final VoidCallback onTermine;

  const DidacticielGrossisteGuide({
    super.key,
    required this.onTermine,
  });

  @override
  Widget build(BuildContext context) {
    return DidacticielGuideOverlay(
      role: RoleActeur.grossiste,
      onTermine: onTermine,
    );
  }
}
