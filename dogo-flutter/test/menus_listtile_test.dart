import 'package:karavan_app/grossiste/ajouter_produit_screen.dart';
import 'package:karavan_app/commercant/aide_support_screen.dart';
import 'package:karavan_app/courtier/assistance_courtier_screen.dart';
import 'package:karavan_app/grossiste/assistance_grossiste_screen.dart';
import 'package:karavan_app/commercant/parametres_commercant_screen.dart';
import 'package:karavan_app/commercant/profil_commercant_screen.dart';
import 'package:karavan_app/courtier/courtier_profil_screen.dart';
import 'package:karavan_app/courtier/parametres_courtier_screen.dart';
import 'package:karavan_app/grossiste/grossiste_drawer.dart';
import 'package:karavan_app/grossiste/grossiste_profil_screen.dart';
import 'package:karavan_app/grossiste/parametres_grossiste_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les menus en ListTile sont posés sur un Material : sinon Flutter lève
/// « ListTile background color or ink splashes may be invisible ».
void main() {
  final ecrans = <String, Widget>{
    'Profil commerçant': const ProfilCommercantScreen(),
    'Paramètres commerçant': const ParametresCommercantScreen(),
    'Profil courtier': const CourtierProfilScreen(),
    'Paramètres courtier': const ParametresCourtierScreen(),
    'Profil grossiste': const GrossisteProfilScreen(),
    'Paramètres grossiste': const ParametresGrossisteScreen(),
    'Menu latéral grossiste': const Scaffold(body: GrossisteDrawer()),
    'Aide commerçant': const AideSupportScreen(),
    'Assistance courtier': const AssistanceCourtierScreen(),
    'Assistance grossiste': const AssistanceGrossisteScreen(),
    'Ajouter un produit (variantes)': const AjouterProduitScreen(),
  };

  for (final MapEntry(key: nom, value: ecran) in ecrans.entries) {
    testWidgets(nom, (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final erreurs = <String>[];
      final precedent = FlutterError.onError;
      FlutterError.onError = (d) => erreurs.add(d.exceptionAsString());
      addTearDown(() => FlutterError.onError = precedent);
      await tester.pumpWidget(MaterialApp(home: ecran));
      await tester.pump(const Duration(milliseconds: 500));
      FlutterError.onError = precedent;
      expect(erreurs.where((e) => e.contains('ListTile background color')), isEmpty);
    });
  }
}
