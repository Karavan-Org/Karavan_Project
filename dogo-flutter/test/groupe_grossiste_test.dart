import 'package:dogo_app/grossiste/creer_groupe_grossiste_screen.dart';
import 'package:dogo_app/services/lien_groupe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("Lien d'invitation : lien web, schéma dogo://, code et numéro", () {
    expect(LienGroupe.extraireId(LienGroupe.lien(42)), 42);
    expect(LienGroupe.extraireId('dogo://groupe/7'), 7);
    expect(LienGroupe.extraireId('Rejoignez-nous : https://dogo.ml/groupe/15 merci'), 15);
    expect(LienGroupe.extraireId('dogo-9'), 9);
    expect(LienGroupe.extraireId(' 31 '), 31);
    expect(LienGroupe.extraireId('bonjour'), isNull);
  });

  testWidgets("Le prix de gros et le stock du produit pré-remplissent le groupe", (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CreerGroupeGrossisteScreen(produit: {
        'id': 3,
        'nom': 'Sandales',
        'prixGros': 4000,
        'variantes': [
          {'id': 1, 'qteDisponible': 12},
          {'id': 2, 'qteDisponible': 8},
        ],
      }),
    ));

    expect(find.text('Achat groupé Sandales'), findsOneWidget);
    expect(find.text('20'), findsOneWidget); // objectif = stock total
    expect(find.text('4000'), findsOneWidget); // prix par pièce = prix de gros
    await tester.scrollUntilVisible(find.text('Créer le groupe'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Créer le groupe'), findsOneWidget);
  });

  testWidgets("RG-27 : le minimum par commerçant ne dépasse pas l'objectif", (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CreerGroupeGrossisteScreen(produit: {
        'id': 3,
        'nom': 'Sandales',
        'prixGros': 4000,
        'variantes': [
          {'id': 1, 'qteDisponible': 20},
        ],
      }),
    ));
    await tester.enterText(find.widgetWithText(TextFormField, '20'), '5');
    await tester.enterText(find.widgetWithText(TextFormField, '1'), '10');
    await tester.scrollUntilVisible(find.text('Créer le groupe'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Créer le groupe'));
    await tester.pump();
    expect(find.text('≤ objectif', skipOffstage: false), findsOneWidget);
  });
}
