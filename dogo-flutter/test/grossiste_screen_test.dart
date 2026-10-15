import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/grossiste/grossiste_main_nav.dart';

void main() {
  testWidgets('GrossisteMainNav renders properly on desktop browser', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: GrossisteMainNav(),
      ),
    );
    await tester.pump();

    expect(find.byType(GrossisteMainNav), findsOneWidget);
    expect(find.text("Espace Grossiste"), findsOneWidget);
    expect(find.text("Accueil"), findsOneWidget);
    expect(find.text("Catalogue"), findsOneWidget);
    expect(find.text("Lots & Ventes"), findsOneWidget);
    expect(find.text("Profil"), findsOneWidget);
    expect(find.text("Mon Catalogue Actif"), findsOneWidget);
  });
}

