import 'dart:io';

import 'package:dogo_app/grossiste/grossiste_connexion_screen.dart';
import 'package:dogo_app/grossiste/grossiste_documents_kyc_screen.dart';
import 'package:dogo_app/grossiste/grossiste_dossier_examen_screen.dart';
import 'package:dogo_app/grossiste/grossiste_inscription_screen.dart';
import 'package:dogo_app/services/kyc_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les écrans d'arrivée du Grossiste tiennent sur l'écran des maquettes (390×844) sans débordement.
/// La vraie police Roboto est chargée : la police de test par défaut fausserait les largeurs de texte.
void main() {
  setUpAll(() async {
    final polices = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    final roboto = FontLoader('Roboto');
    for (final f in ['roboto-regular.ttf', 'roboto-bold.ttf', 'roboto-medium.ttf']) {
      final fichier = File('$polices/$f');
      expect(fichier.existsSync(), isTrue, reason: fichier.path);
      roboto.addFont(Future.value(ByteData.sublistView(fichier.readAsBytesSync())));
    }
    await roboto.load();
  });

  Future<void> afficher(WidgetTester tester, Widget ecran) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      routes: {
        '/grossiste/connexion': (_) => const Scaffold(body: Text("Écran Connexion")),
      },
      home: ecran,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Connexion', (tester) async {
    await afficher(tester, const GrossisteConnexionScreen());
    expect(find.text('Bienvenue Grossiste !'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('Inscription', (tester) async {
    await afficher(tester, const GrossisteInscriptionScreen());
    expect(find.text('Créer mon compte'), findsOneWidget);
  });

  testWidgets('Soumettre mes documents (avec motif de rejet)', (tester) async {
    await afficher(tester, const GrossisteDocumentsKycScreen(motifRejet: 'NIF illisible'));
    expect(find.text('Soumettre mes documents'), findsOneWidget);
    expect(find.text('Ajouter un document'), findsOneWidget);
    await tester.tap(find.text('Soumettre'));
    await tester.pump();
    expect(find.textContaining('Pièces obligatoires manquantes'), findsOneWidget);
  });

  testWidgets('Dossier en examen', (tester) async {
    await afficher(
      tester,
      const GrossisteDossierExamenScreen(
        dossier: DossierKyc(id: 7, statut: 'EN_ATTENTE', typesDocuments: ['PIECE_IDENTITE', 'REGISTRE_COMMERCE', 'NIF']),
      ),
    );
    expect(find.text('DOSSIER EN EXAMEN'), findsOneWidget);
    expect(find.text('RCCM & NIF & pièce d\'identité enregistrés'), findsOneWidget);
  });

  testWidgets('Dossier approuvé remplit la 3eme jauge et affiche la notification', (tester) async {
    await afficher(
      tester,
      const GrossisteDossierExamenScreen(
        dossier: DossierKyc(id: 7, statut: 'APPROUVE', typesDocuments: ['PIECE_IDENTITE', 'REGISTRE_COMMERCE', 'NIF']),
      ),
    );
    // Le dialogue de notification de validation s'affiche
    expect(find.text('Compte Grossiste Validé !'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);

    // La jauge 3 est validée et le badge indique le succès sur l'écran
    expect(find.text('DOSSIER APPROUVÉ & VALIDÉ'), findsOneWidget);
    expect(find.text('3. Ventes'), findsOneWidget);
    expect(find.text('Validé & Actif'), findsOneWidget);

    // Au clic sur "Continuer", le grossiste est redirigé vers l'écran de connexion
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Écran Connexion'), findsOneWidget);
  });
}
