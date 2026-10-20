import 'package:dogo_app/models/role_acteur.dart';
import 'package:dogo_app/widgets/didacticiel_guide_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DidacticielGuideOverlay pour Commercant navigation complète', (tester) async {
    bool termine = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DidacticielGuideOverlay(
            role: RoleActeur.commercant,
            onTermine: () {
              termine = true;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Étape 1 : But application Commerçant
    expect(find.text('Bienvenue sur Karavan Commerçant !'), findsOneWidget);
    expect(find.text("LE BUT DE L'APPLICATION"), findsOneWidget);
    expect(find.text('ÉTAPE 1 / 5'), findsOneWidget);

    // Clic sur Suivant -> Étape 2 : Explorer
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Explorer & Trouver des Produits'), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 1 : LE CATALOGUE'), findsOneWidget);

    // Clic sur Suivant -> Étape 3 : Bouton (+)
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Rejoindre ou Ouvrir un Groupe'), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 2 : LE BOUTON (+)'), findsOneWidget);

    // Clic sur Suivant -> Étape 4 : Commandes
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Suivi en Direct de vos Colis'), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 3 : MES COMMANDES'), findsOneWidget);

    // Clic sur Suivant -> Étape 5 : Portefeuille & Séquestre
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Portefeuille & Séquestre Garanti'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);

    // Terminer
    await tester.tap(find.text('Terminer'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(termine, isTrue);
  });

  testWidgets('DidacticielGuideOverlay pour Courtier navigation complète', (tester) async {
    bool termine = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DidacticielGuideOverlay(
            role: RoleActeur.courtier,
            onTermine: () {
              termine = true;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Étape 1
    expect(find.text('Bienvenue sur Karavan Courtier !'), findsOneWidget);
    expect(find.text('ÉTAPE 1 / 5'), findsOneWidget);

    // Passer le guide
    expect(find.text('Passer le guide'), findsOneWidget);
    await tester.tap(find.text('Passer le guide'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(termine, isTrue);
  });
}

