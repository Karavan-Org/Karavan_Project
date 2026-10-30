import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../screens/parametres_compte_screen.dart';

/// Paramètres du compte courtier : écran commun aux trois rôles, alimenté par /api/moi.
class ParametresCourtierScreen extends StatelessWidget {
  const ParametresCourtierScreen({super.key});

  @override
  Widget build(BuildContext context) => const ParametresCompteScreen(role: RoleActeur.courtier);
}
