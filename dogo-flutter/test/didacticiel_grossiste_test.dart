import 'package:dogo_app/grossiste/didacticiel_grossiste_guide.dart';
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

    // Étape 1 : Le but de l'application
    expect(find.text('Bienvenue sur DoGo Vendeur !'), findsOneWidget);
    expect(find.text("LE BUT DE L'APPLICATION"), findsOneWidget);
    expect(find.text('ÉTAPE 1 / 5'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);

    // Clic sur Suivant -> Étape 2 : Catalogue
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Votre Catalogue & Variantes'), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 1 : PRODUITS'), findsOneWidget);
    expect(find.text('ÉTAPE 2 / 5'), findsOneWidget);
    expect(find.text('Précédent'), findsOneWidget);

    // Clic sur Suivant -> Étape 3 : Bouton (+)
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Créer un Groupe d'Achat"), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 2 : LE BOUTON (+)'), findsOneWidget);

    // Clic sur Suivant -> Étape 4 : Commandes
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Validation & Expédition'), findsOneWidget);

    // Clic sur Suivant -> Étape 5 : Portefeuille
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Portefeuille & Séquestre Garanti'), findsOneWidget);
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

