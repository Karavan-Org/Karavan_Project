import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/screens/detail_groupe_screen.dart';
import 'package:dogo_app/services/groupe_api_service.dart';

void main() {
  testWidgets('DetailGroupeScreen affiche la maquette exacte du groupe', (tester) async {
    final groupeTest = GroupeResume(
      id: 4092,
      titre: "Sneakers Runner Pro",
      statut: "OBJECTIF_ATTEINT",
      produitNom: "Sneakers Runner Pro",
      quantiteCible: 600,
      quantiteConfirmee: 600,
      prixUnitaire: 6500,
      dateOuverture: DateTime.now().subtract(const Duration(days: 9)),
      porteParGrossiste: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DetailGroupeScreen(groupe: groupeTest),
      ),
    );

    // Vérification du Header
    expect(find.text("Détail du groupe"), findsOneWidget);
    expect(find.textContaining("#DG-4092"), findsOneWidget);
    expect(find.textContaining("Créé il y a 9 jours"), findsOneWidget);

    // Vérification de la carte Résumé
    expect(find.text("Sneakers Runner Pro"), findsOneWidget);
    expect(find.textContaining("6 500 FCFA / unité"), findsOneWidget);
    expect(find.text("100%"), findsOneWidget);
    expect(find.text("Volume réservé"), findsOneWidget);
    expect(find.text("600/600 pcs"), findsOneWidget);
    expect(find.text("Fermée"), findsOneWidget);
    expect(find.textContaining("3 900 000 FCFA"), findsWidgets);
    expect(
      find.textContaining("600 pcs de votre stock sont actuellement réservées"),
      findsOneWidget,
    );

    // Vérification de la carte Fonds sous séquestre
    expect(find.textContaining("Total des fonds sous séquestre"), findsOneWidget);
    expect(find.text("(Garantis)"), findsOneWidget);

    // Vérification de la section Commandes enregistrées
    expect(find.textContaining("Commandes enregistrées"), findsOneWidget);

    // Vérification du bouton Notifier
    expect(find.text("Notifier"), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
  });
}

