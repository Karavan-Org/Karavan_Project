import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/models/niveau_commercant.dart';
import 'package:dogo_app/commercant/details_niveau_commercant_sheet.dart';
import 'package:dogo_app/commercant/profil_commercant_screen.dart';

void main() {
  group('NiveauCommercant - Logique métier des paliers', () {
    test('Palier Niveau 1 (< 5 commandes)', () {
      expect(NiveauCommercant.calculer(0), equals(NiveauCommercant.niveau1));
      expect(NiveauCommercant.calculer(1), equals(NiveauCommercant.niveau1));
      expect(NiveauCommercant.calculer(4), equals(NiveauCommercant.niveau1));

      const n1 = NiveauCommercant.niveau1;
      expect(n1.commandesRestantesPourSuivant(0), equals(5));
      expect(n1.commandesRestantesPourSuivant(3), equals(2));
      expect(n1.pourcentageProgression(0), equals(0));
      expect(n1.pourcentageProgression(3), equals(60));
    });

    test('Palier Niveau 2 (5 à 19 commandes)', () {
      expect(NiveauCommercant.calculer(5), equals(NiveauCommercant.niveau2));
      expect(NiveauCommercant.calculer(12), equals(NiveauCommercant.niveau2));
      expect(NiveauCommercant.calculer(19), equals(NiveauCommercant.niveau2));

      const n2 = NiveauCommercant.niveau2;
      expect(n2.commandesRestantesPourSuivant(12), equals(8));
      expect(n2.pourcentageProgression(12), equals(60));
      expect(n2.nomNiveauSuivant, equals('Niveau 3 • VIP'));
    });

    test('Palier Niveau 3 (>= 20 commandes)', () {
      expect(NiveauCommercant.calculer(20), equals(NiveauCommercant.niveau3));
      expect(NiveauCommercant.calculer(35), equals(NiveauCommercant.niveau3));

      const n3 = NiveauCommercant.niveau3;
      expect(n3.commandesRestantesPourSuivant(25), equals(0));
      expect(n3.progression(25), equals(1.0));
      expect(n3.nomNiveauSuivant, isNull);
    });
  });

  group('DetailsNiveauCommercantSheet - Interface & interactions', () {
    testWidgets('Affiche les détails du Niveau 2 et la progression vers Niveau 3', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DetailsNiveauCommercantSheet(
              nbCommandes: 12,
              niveau: NiveauCommercant.niveau2,
            ),
          ),
        ),
      );

      // Vérifie les libellés de l'en-tête
      expect(find.text("Niveau Commerçant"), findsOneWidget);
      expect(find.text("Commerçant Vérifié"), findsOneWidget);
      expect(find.text("60%"), findsOneWidget);
      expect(find.text("12 commande(s) réalisée(s)"), findsOneWidget);
      expect(find.text("Objectif : 20 commandes"), findsOneWidget);
      expect(find.text("Plus que 8 commande(s) pour atteindre le Niveau 3 • VIP !"), findsOneWidget);

      // Vérifie les 3 paliers
      expect(find.text("0 à 4 commandes"), findsOneWidget);
      expect(find.text("5 à 19 commandes"), findsOneWidget);
      expect(find.text("20 commandes et +"), findsOneWidget);
      expect(find.text("Votre niveau"), findsOneWidget);

      // Vérifie le bouton d'action
      expect(find.text("Explorer les groupes d'achat"), findsOneWidget);
    });

    testWidgets('ProfilCommercantScreen ouvre la feuille au tap sur le badge de niveau', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfilCommercantScreen(),
        ),
      );

      await tester.pump();

      // Sans commande (nouveau compte), le commerçant est au Niveau 1 : jamais une valeur de maquette
      expect(find.text("Niveau 2"), findsNothing);
      final badgeFinder = find.text("Niveau 1");
      expect(badgeFinder, findsOneWidget);

      // On clique dessus pour ouvrir la feuille
      await tester.tap(badgeFinder);
      await tester.pumpAndSettle();

      // La feuille de détails du niveau s'affiche
      expect(find.text("Niveau Commerçant"), findsOneWidget);
      expect(find.text("Paliers de fidélité Karavan"), findsOneWidget);
    });

    testWidgets("Taper sur Explorer les groupes d'achat déclenche onExplorer", (tester) async {
      bool onExplorerAppele = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetailsNiveauCommercantSheet(
              nbCommandes: 10,
              niveau: NiveauCommercant.niveau2,
              onExplorer: () {
                onExplorerAppele = true;
              },
            ),
          ),
        ),
      );

      final boutonExplorer = find.text("Explorer les groupes d'achat");
      expect(boutonExplorer, findsOneWidget);

      await tester.ensureVisible(boutonExplorer);
      await tester.pumpAndSettle();

      await tester.tap(boutonExplorer);
      await tester.pumpAndSettle();

      expect(onExplorerAppele, isTrue);
    });
  });
}

