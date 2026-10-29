import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/main.dart';
import 'package:karavan_app/screens/splash_launch_screen.dart';
import 'package:karavan_app/screens/onboarding_screen.dart';

void main() {
  testWidgets('KaravanApp démarre sur SplashLaunchScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const KaravanApp());
    expect(find.byType(SplashLaunchScreen), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche la navigation de démarrage', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
  });
}
