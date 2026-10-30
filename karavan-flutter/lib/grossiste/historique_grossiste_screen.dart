import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../widgets/historique_groupes.dart';

/// Historique du grossiste : groupes clos lus sur le serveur (écran commun courtier / grossiste).
class HistoriqueGrossisteScreen extends StatelessWidget {
  const HistoriqueGrossisteScreen({super.key});

  @override
  Widget build(BuildContext context) => const HistoriqueGroupesScreen(role: RoleActeur.grossiste);
}
