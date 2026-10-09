import 'package:flutter/material.dart';
import 'mes_groupes_grossiste_screen.dart';

/// Validation de la disponibilité du stock (RG-18) : les groupes du grossiste qui attendent sa confirmation.
class ValidationStockGrossisteScreen extends StatelessWidget {
  const ValidationStockGrossisteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MesGroupesGrossisteScreen(titre: "Validation du stock", filtreInitial: "À confirmer");
  }
}
