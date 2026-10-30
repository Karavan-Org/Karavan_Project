import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../widgets/historique_groupes.dart';

/// Historique du courtier : groupes clos lus sur le serveur (écran commun courtier / grossiste).
class HistoriqueCourtierScreen extends StatelessWidget {
  const HistoriqueCourtierScreen({super.key});

  @override
  Widget build(BuildContext context) => const HistoriqueGroupesScreen(role: RoleActeur.courtier);
}
