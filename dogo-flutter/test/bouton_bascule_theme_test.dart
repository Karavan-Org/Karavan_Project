import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/widgets/bouton_bascule_theme.dart';
import 'package:dogo_app/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BoutonBasculeTheme - Animations Soleil Rayonnant & Lune Lumineuse', () {
    testWidgets('affiche le soleil rayonnant en mode clair et la lune lumineuse en mode sombre', (tester) async {
      ThemeService.instance.themeModeNotifier.value = ThemeMode.light;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: Center(
              child: BoutonBasculeTheme(compact: true),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Doit afficher la clé du soleil rayonnant
      expect(find.byKey(const ValueKey("soleil_rayonnant_compact")), findsOneWidget);
      expect(find.byKey(const ValueKey("lune_lumineuse_compact")), findsNothing);

      // Clic pour basculer en mode sombre
      await tester.tap(find.byType(BoutonBasculeTheme));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(ThemeService.instance.themeModeNotifier.value, ThemeMode.dark);
      expect(find.byKey(const ValueKey("lune_lumineuse_compact")), findsOneWidget);
      expect(find.byKey(const ValueKey("soleil_rayonnant_compact")), findsNothing);
    });

    testWidgets('affiche le format carte étendu en mode non-compact', (tester) async {
      ThemeService.instance.themeModeNotifier.value = ThemeMode.dark;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: Center(
              child: BoutonBasculeTheme(compact: false),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey("lune_lumineuse_full")), findsOneWidget);
      expect(find.text("Sombre"), findsOneWidget);
      expect(find.text("Actif"), findsOneWidget);

      // Clic pour repasser en mode clair
      await tester.tap(find.byType(BoutonBasculeTheme));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(ThemeService.instance.themeModeNotifier.value, ThemeMode.light);
      expect(find.byKey(const ValueKey("soleil_rayonnant_full")), findsOneWidget);
      expect(find.text("Clair"), findsOneWidget);
    });
  });
}
