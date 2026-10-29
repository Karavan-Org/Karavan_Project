import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/widgets/bouton_bascule_theme.dart';
import 'package:karavan_app/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget bouton, ThemeMode mode) => MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: mode,
        home: Scaffold(body: Center(child: bouton)),
      );

  group('BoutonBasculeTheme', () {
    testWidgets('compact : la lune propose le mode sombre, le soleil le mode clair', (tester) async {
      ThemeService.instance.themeModeNotifier.value = ThemeMode.light;
      await tester.pumpWidget(app(const BoutonBasculeTheme(compact: true), ThemeMode.light));

      expect(find.byKey(const ValueKey('theme_clair')), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

      await tester.tap(find.byType(BoutonBasculeTheme));
      await tester.pumpAndSettle();

      expect(ThemeService.instance.themeModeNotifier.value, ThemeMode.dark);
      expect(find.byKey(const ValueKey('theme_sombre')), findsOneWidget);
    });

    testWidgets('format étendu : affiche le mode actif en toutes lettres', (tester) async {
      ThemeService.instance.themeModeNotifier.value = ThemeMode.dark;
      await tester.pumpWidget(app(const BoutonBasculeTheme(compact: false), ThemeMode.dark));

      expect(find.text('Mode sombre'), findsOneWidget);

      await tester.tap(find.byType(BoutonBasculeTheme));
      await tester.pumpAndSettle();

      expect(ThemeService.instance.themeModeNotifier.value, ThemeMode.light);
      expect(find.text('Mode clair'), findsOneWidget);
    });
  });
}
