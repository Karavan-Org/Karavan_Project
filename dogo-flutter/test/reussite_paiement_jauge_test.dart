import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/commercant/reussite_paiement_screen.dart';

void main() {
  group('Jauge dynamique et réactive de ReussitePaiementScreen', () {
    testWidgets('Affiche la progression réelle du groupe avec le bon pourcentage', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ReussitePaiementScreen(
            participationId: 16,
            titreProduit: 'Achat groupé BOTTES',
            paysOrigine: 'Mali',
            prixUnitaire: 31675,
            quantite: 13,
            montantTotal: 411775,
            moyenPaiement: 'Portefeuille Achats',
            dateHeure: "Aujourd'hui - 16:14",
            piecesActuelles: 13,
            piecesObjectif: 25,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Vérifier le titre et les détails du paiement
      expect(find.text('Paiement effectué\navec succès !'), findsOneWidget);
      expect(find.text('Achat groupé BOTTES'), findsOneWidget);
      expect(find.text('13 pièces'), findsOneWidget);
      expect(find.text('#16'), findsOneWidget);

      // Vérifier la jauge dynamique : 13 / 25 pièces = 52% (et NON 78% statique)
      expect(find.text('13 / 25 pièces'), findsOneWidget);
      expect(find.text('52%'), findsOneWidget);
      expect(find.text('Groupe en cours'), findsOneWidget);
      expect(find.textContaining('Plus que 12 pièces pour clôturer le groupe'), findsOneWidget);

      // S'assurer qu'aucun ancien texte 780 ou 78% n'apparaît
      expect(find.text('78%'), findsNothing);
      expect(find.textContaining('780'), findsNothing);
    });

    testWidgets('Affiche Objectif atteint à 100% quand le groupe est complété', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ReussitePaiementScreen(
            participationId: 17,
            titreProduit: 'Achat groupé BOTTES',
            paysOrigine: 'Mali',
            prixUnitaire: 31675,
            quantite: 12,
            montantTotal: 380100,
            moyenPaiement: 'Orange Money',
            dateHeure: "Aujourd'hui - 16:20",
            piecesActuelles: 25,
            piecesObjectif: 25,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Vérifier 25 / 25 pièces = 100%
      expect(find.text('25 / 25 pièces'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Objectif atteint 🎉'), findsOneWidget);
      expect(find.textContaining('Objectif 100% atteint ! Expédition garantie 🚀'), findsOneWidget);
    });

    testWidgets('Gère proprement le cas où piecesObjectif est 0 sans planter', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ReussitePaiementScreen(
            participationId: 18,
            titreProduit: 'Produit Inconnu',
            prixUnitaire: 10000,
            quantite: 2,
            montantTotal: 20000,
            moyenPaiement: 'Moov Money',
            dateHeure: "Aujourd'hui",
            piecesActuelles: 0,
            piecesObjectif: 0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Paiement effectué\navec succès !'), findsOneWidget);
      expect(find.text('Produit Inconnu'), findsOneWidget);
      // Ne doit pas afficher de fausse jauge à 78%
      expect(find.text('78%'), findsNothing);
    });
  });
}

