import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/services/theme_service.dart';
import 'package:karavan_app/theme/app_theme.dart';
import 'package:karavan_app/widgets/bouton_bascule_theme.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ThemeService - Logique de bascule et persistance', () {
    test('Changement de mode réactif', () async {
      final service = ThemeService.instance;

      await service.changerMode(ThemeMode.dark);
      expect(service.modeActuel, equals(ThemeMode.dark));

      await service.changerMode(ThemeMode.light);
      expect(service.modeActuel, equals(ThemeMode.light));

      await service.changerMode(ThemeMode.system);
      expect(service.modeActuel, equals(ThemeMode.system));

      // Remise en light pour les tests suivants
      await service.changerMode(ThemeMode.light);
    });

    test('AppTheme fournit lightTheme et darkTheme conformes Material 3', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, equals(Brightness.light));
      expect(dark.brightness, equals(Brightness.dark));
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);

      expect(dark.scaffoldBackgroundColor, equals(AppTheme.darkBackground));
      expect(dark.colorScheme.primary, equals(AppTheme.darkPrimary));
      expect(dark.colorScheme.surface, equals(AppTheme.darkSurface));
    });

    testWidgets('BoutonBasculeTheme bascule entre clair et sombre au tap', (tester) async {
      await ThemeService.instance.changerMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [
                BoutonBasculeTheme(compact: true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(BoutonBasculeTheme), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

      // Tap pour passer en mode sombre
      await tester.tap(find.byType(BoutonBasculeTheme));
      await tester.pumpAndSettle();

      expect(ThemeService.instance.modeActuel, equals(ThemeMode.dark));
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);

      // Tap pour repasser en mode clair
      await tester.tap(find.byType(BoutonBasculeTheme));
      await tester.pumpAndSettle();

      expect(ThemeService.instance.modeActuel, equals(ThemeMode.light));
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    });
  });
}
