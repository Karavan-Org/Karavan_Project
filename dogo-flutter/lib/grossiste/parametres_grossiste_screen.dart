import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../screens/parametres_compte_screen.dart';

/// Paramètres du compte grossiste : écran commun aux trois rôles, alimenté par /api/moi.
class ParametresGrossisteScreen extends StatelessWidget {
  const ParametresGrossisteScreen({super.key});

  @override
  Widget build(BuildContext context) => const ParametresCompteScreen(role: RoleActeur.grossiste);
}
