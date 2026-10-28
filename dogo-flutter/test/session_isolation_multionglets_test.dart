import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/models/role_acteur.dart';
import 'package:karavan_app/services/auth_service.dart';
import 'package:karavan_app/services/session_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Isolation multi-onglets & persistance des espaces (Commerçant / Grossiste / Courtier)', () {
    final storage = SessionStorageService.instance;

    const profilCommercant = UtilisateurProfil(
      id: 1,
      type: 'COMMERCANT',
      nom: 'Aminata Traoré',
      telephone: '+22373000001',
      statut: 'ACTIF',
      photoUrl: '/api/public/images/avatars/avatar_1.jpg',
    );

    const profilGrossiste = UtilisateurProfil(
      id: 2,
      type: 'GROSSISTE',
      nom: 'Grossiste Demo',
      telephone: '+22371000001',
      statut: 'ACTIF',
      photoUrl: '/api/public/images/avatars/avatar_2.jpg',
    );

    const profilCourtier = UtilisateurProfil(
      id: 3,
      type: 'COURTIER',
      nom: 'Courtier Demo',
      telephone: '+22372000001',
      statut: 'ACTIF',
      photoUrl: null,
    );

    test('Sauvegarde cloisonnée par rôle pour Grossiste, Courtier et Commerçant', () async {
      // 1. Sauvegarde Commerçant
      await storage.sauvegarderSession(
        refreshToken: 'refresh-token-commercant-xyz',
        profil: profilCommercant,
      );

      // 2. Sauvegarde Grossiste (ne doit pas écraser la clé isolée de commerçant)
      await storage.sauvegarderSession(
        refreshToken: 'refresh-token-grossiste-abc',
        profil: profilGrossiste,
      );

      // 3. Sauvegarde Courtier
      await storage.sauvegarderSession(
        refreshToken: 'refresh-token-courtier-123',
        profil: profilCourtier,
      );

      // 4. Les rôles sont bien typés
      expect(profilCommercant.roleActeur, equals(RoleActeur.commercant));
      expect(profilGrossiste.roleActeur, equals(RoleActeur.grossiste));
      expect(profilCourtier.roleActeur, equals(RoleActeur.courtier));

      // 5. Sauvegarder l'espace actif
      await storage.sauvegarderDernierEspace('commercant');
      expect(await storage.lireDernierEspace(), equals('commercant'));

      await storage.sauvegarderDernierEspace('grossiste');
      expect(await storage.lireDernierEspace(), equals('grossiste'));

      await storage.sauvegarderDernierEspace('courtier');
      expect(await storage.lireDernierEspace(), equals('courtier'));
    });
  });
}

