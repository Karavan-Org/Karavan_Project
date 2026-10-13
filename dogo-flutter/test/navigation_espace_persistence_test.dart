import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/services/session_storage_service.dart';

void main() {
  group('SessionStorageService - Persistance de l\'espace actif', () {
    test('Sauvegarde et lit l\'espace courtier', () async {
      await SessionStorageService.instance.sauvegarderDernierEspace('courtier');
      final espace = await SessionStorageService.instance.lireDernierEspace();
      expect(espace, equals('courtier'));
    });

    test('Sauvegarde et lit l\'espace commercant', () async {
      await SessionStorageService.instance.sauvegarderDernierEspace('commercant');
      final espace = await SessionStorageService.instance.lireDernierEspace();
      expect(espace, equals('commercant'));
    });

    test('Sauvegarde et lit l\'espace grossiste', () async {
      await SessionStorageService.instance.sauvegarderDernierEspace('grossiste');
      final espace = await SessionStorageService.instance.lireDernierEspace();
      expect(espace, equals('grossiste'));
    });

    test('Efface la session et réinitialise l\'espace actif', () async {
      await SessionStorageService.instance.sauvegarderDernierEspace('courtier');
      await SessionStorageService.instance.effacerSession();
      final espace = await SessionStorageService.instance.lireDernierEspace();
      expect(espace, isNull);
    });
  });
}

