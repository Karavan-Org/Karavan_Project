import 'package:karavan_app/models/role_acteur.dart';
import 'package:karavan_app/services/session_storage_service.dart';
import 'package:karavan_app/widgets/didacticiel_guide_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
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
    await tester.pumpWidget(const SizedBox());
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
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('DidacticielGuideOverlay pour Grossiste navigation complète (Tableau de bord, Catalogue, FAB, Tabs & Menu)', (tester) async {
    bool termine = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DidacticielGuideOverlay(
            role: RoleActeur.grossiste,
            onTermine: () {
              termine = true;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Étape 1 : Tableau de bord & Chiffres clés (KPI)
    expect(find.text('Tableau de Bord & Chiffres Clés'), findsOneWidget);
    expect(find.text('TABLEAU DE BORD : STATISTIQUES'), findsOneWidget);
    expect(find.text('ÉTAPE 1 / 6'), findsOneWidget);

    // Clic Suivant -> Étape 2 : Mon Catalogue Actif
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Mon Catalogue Actif & Ajout'), findsOneWidget);
    expect(find.text('VOS PRODUITS & STOCKS'), findsOneWidget);
    expect(find.text('ÉTAPE 2 / 6'), findsOneWidget);

    // Clic Suivant -> Étape 3 : Créer un groupe (+)
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Créer un Groupe d'Achat"), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 2 : LE BOUTON (+)'), findsOneWidget);
    expect(find.text('ÉTAPE 3 / 6'), findsOneWidget);

    // Clic Suivant -> Étape 4 : Validation & Expédition (Commandes)
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Validation & Expédition'), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 3 : COMMANDES & STOCKS'), findsOneWidget);
    expect(find.text('ÉTAPE 4 / 6'), findsOneWidget);

    // Clic Suivant -> Étape 5 : Portefeuille & Séquestre
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Portefeuille & Séquestre Garanti'), findsOneWidget);
    expect(find.text('FONCTIONNALITÉ 4 : PAIEMENTS & VIREMENTS'), findsOneWidget);
    expect(find.text('ÉTAPE 5 / 6'), findsOneWidget);

    // Clic Suivant -> Étape 6 : Menu, Paramètres & Mode Sombre (En-tête)
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Menu, Paramètres & Mode Sombre'), findsOneWidget);
    expect(find.text('VOTRE EN-TÊTE PERSONNEL'), findsOneWidget);
    expect(find.text('ÉTAPE 6 / 6'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);

    // Terminer
    await tester.tap(find.text('Terminer'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(termine, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Didacticiel non terminé ne marque pas le guide comme vu (relance à la prochaine ouverture)', (tester) async {
    const identifiant = 'user_incomplet_123';
    await SessionStorageService.instance.reinitialiserGuide('commercant', identifiant);

    bool vuInitial = await SessionStorageService.instance.aDejaVuGuide('commercant', identifiant);
    expect(vuInitial, isFalse);

    // Démarrage de l'overlay mais interruption à l'étape 2 sans passer ni terminer
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DidacticielGuideOverlay(
            role: RoleActeur.commercant,
            onTermine: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Passe à l'étape 2
    await tester.tap(find.text('Suivant'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ÉTAPE 2 / 5'), findsOneWidget);

    // Le guide ne doit PAS être marqué comme vu tant qu'il n'est pas terminé ou passé
    bool vuApresEtape2 = await SessionStorageService.instance.aDejaVuGuide('commercant', identifiant);
    expect(vuApresEtape2, isFalse);

    // Démonter le widget pour libérer les AnimationController répétitifs
    await tester.pumpWidget(const SizedBox());
  });
}

