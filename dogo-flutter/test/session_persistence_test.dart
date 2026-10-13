import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dogo_app/services/session_storage_service.dart';
import 'package:dogo_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('SessionStorageService sauvegarde, lit et efface la session', () async {
    const profil = UtilisateurProfil(
      id: 42,
      type: 'GROSSISTE',
      nom: 'Sidi Diawara',
      telephone: '+22370000002',
      statut: 'ACTIF',
      permissions: ['CAMPAGNE_CREER'],
    );

    // Initialement vide
    expect(await SessionStorageService.instance.lireRefreshToken(), isNull);
    expect(await SessionStorageService.instance.lireProfil(), isNull);

    // Sauvegarde
    await SessionStorageService.instance.sauvegarderSession(
      refreshToken: 'test-refresh-token-12345',
      profil: profil,
    );

    // Lecture
    final token = await SessionStorageService.instance.lireRefreshToken();
    expect(token, 'test-refresh-token-12345');

    final profilLu = await SessionStorageService.instance.lireProfil();
    expect(profilLu, isNotNull);
    expect(profilLu!.id, 42);
    expect(profilLu.type, 'GROSSISTE');
    expect(profilLu.nom, 'Sidi Diawara');

    // Effacement (déconnexion)
    await SessionStorageService.instance.effacerSession();
    expect(await SessionStorageService.instance.lireRefreshToken(), isNull);
    expect(await SessionStorageService.instance.lireProfil(), isNull);
  });
}

