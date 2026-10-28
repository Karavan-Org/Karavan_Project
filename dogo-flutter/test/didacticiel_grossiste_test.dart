import 'package:karavan_app/grossiste/didacticiel_grossiste_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DidacticielGrossisteGuide navigation et validation étape par étape', (tester) async {
    bool termine = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DidacticielGrossisteGuide(
            onTermine: () {
              termine = true;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Étape 1 : tableau de bord et chiffres clés
    expect(find.text('Tableau de Bord & Chiffres Clés'), findsOneWidget);
    expect(find.text('TABLEAU DE BORD : STATISTIQUES'), findsOneWidget);
    expect(find.text('ÉTAPE 1 / 6'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);

    Future<void> suivant() async {
      await tester.tap(find.text('Suivant'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Étape 2 : catalogue actif
    await suivant();
    expect(find.text('Mon Catalogue Actif & Ajout'), findsOneWidget);
    expect(find.text('VOS PRODUITS & STOCKS'), findsOneWidget);
    expect(find.text('ÉTAPE 2 / 6'), findsOneWidget);
    expect(find.text('Précédent'), findsOneWidget);

    // Étape 3 : bouton (+)
    await suivant();
    expect(find.text("Créer un Groupe d'Achat"), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 2 : LE BOUTON (+)'), findsOneWidget);

    // Étape 4 : validation et expédition
    await suivant();
    expect(find.text('Validation & Expédition'), findsOneWidget);

    // Étape 5 : portefeuille
    await suivant();
    expect(find.text('Portefeuille & Séquestre Garanti'), findsOneWidget);

    // Étape 6 : en-tête personnel, dernière étape
    await suivant();
    expect(find.text('Menu, Paramètres & Mode Sombre'), findsOneWidget);
    expect(find.text('ÉTAPE 6 / 6'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);

    // Clic sur Terminer
    await tester.tap(find.text('Terminer'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(termine, isTrue);
  });

  testWidgets('DidacticielGrossisteGuide bouton Passer le guide', (tester) async {
    bool termine = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DidacticielGrossisteGuide(
            onTermine: () {
              termine = true;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Passer le guide'), findsOneWidget);
    await tester.tap(find.text('Passer le guide'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(termine, isTrue);
  });
}

