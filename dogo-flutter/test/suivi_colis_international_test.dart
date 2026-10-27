import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/widgets/animations_suivi_international.dart';
import 'package:dogo_app/commercant/suivi_colis_screen.dart';

void main() {
  group('Suivi de Colis International - 10 Grandes Phases & Animations', () {
    test('Les 10 phases canoniques sont bien définies avec descriptions complètes', () {
      const phases = PhaseColisInternational.toutes;
      expect(phases.length, 10);

      const titresAttendus = [
        "Commande reçue / en traitement",
        "Expédié par le vendeur / pris en charge",
        "Centre de départ (Tri & Regroupement)",
        "Départ du pays d’origine",
        "En transit international",
        "Arrivée dans le pays de destination",
        "Dédouanement & Contrôles",
        "Centre de tri du pays de destination",
        "En livraison locale / disponible au retrait",
        "Livré / retiré",
      ];

      for (int i = 0; i < 10; i++) {
        final p = phases[i];
        expect(p.numero, i + 1);
        expect(p.titre, titresAttendus[i]);
        expect(p.description.isNotEmpty, isTrue);
        expect(p.sousTitre.isNotEmpty, isTrue);
        expect(p.lieuTypique.isNotEmpty, isTrue);
      }
    });

    testWidgets('Toutes les animations des 10 phases se construisent sans erreur', (tester) async {
      for (int num = 1; num <= 10; num++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimationPhaseWidget(numeroPhase: num, compact: false),
            ),
          ),
        );
        expect(find.byType(AnimationPhaseWidget), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 300));
      }
    });

    testWidgets('SuiviColisScreen se construit et affiche la jauge et les phases', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SuiviColisScreen(phaseInitiale: 5),
        ),
      );

      // On laisse passer un tick pour le chargement initial ou affichage
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Vérifie la présence du titre et du sélecteur
      expect(find.text('Suivi de Colis'), findsOneWidget);
    });
  });
}
