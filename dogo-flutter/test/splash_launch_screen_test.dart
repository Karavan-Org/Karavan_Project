import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/screens/splash_launch_screen.dart';

void main() {
  group('SplashLaunchScreen - Animation de départ & Design System', () {
    testWidgets('Se construit proprement en mode clair avec la charte graphique', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          themeMode: ThemeMode.light,
          home: SplashLaunchScreen(),
        ),
      );

      // En mode test, l'animation est instantanée ou complétée
      await tester.pump();

      expect(find.byType(SplashLaunchScreen), findsOneWidget);
      expect(find.text('ACHAT GROUPÉ INTERNATIONAL'), findsOneWidget);
    });

    testWidgets('Se construit proprement en mode sombre', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const SplashLaunchScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(SplashLaunchScreen), findsOneWidget);
      expect(find.text('ACHAT GROUPÉ INTERNATIONAL'), findsOneWidget);
    });
  });
}

