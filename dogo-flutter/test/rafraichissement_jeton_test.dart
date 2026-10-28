import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/services/api/api_client.dart';
import 'package:karavan_app/services/api/api_config.dart';
import 'package:karavan_app/services/api/api_exception.dart';
import 'package:karavan_app/services/auth_service.dart';
import 'package:karavan_app/services/session_storage_service.dart';

/// Rafraîchissement du jeton sur 401, contre un vrai serveur HTTP local.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer serveur;
  late List<String> requetes;
  late Future<void> Function(HttpRequest) repondre;

  setUp(() async {
    HttpOverrides.global = null; // flutter_test bloque le réseau réel par défaut
    FlutterSecureStorage.setMockInitialValues({});
    requetes = [];
    serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serveur.listen((r) async {
      requetes.add('${r.method} ${r.uri.path} ${r.headers.value('authorization') ?? '-'}');
      await repondre(r);
    });
    ApiConfig.baseUrlTest = 'http://127.0.0.1:${serveur.port}';
    AuthService.instance; // branche le rafraîchissement automatique du client
    await SessionStorageService.instance.sauvegarderSession(
      refreshToken: 'refresh-1',
      profil: const UtilisateurProfil(id: 7, type: 'COMMERCANT', nom: 'Awa', telephone: '+22373000001', statut: 'ACTIF'),
    );
    ApiClient.instance.definirJeton('jeton-expire');
  });

  tearDown(() async {
    ApiConfig.baseUrlTest = null;
    ApiClient.instance.deconnecter();
    await serveur.close(force: true);
  });

  Future<void> json(HttpRequest r, int statut, [Object? corps]) async {
    r.response.statusCode = statut;
    r.response.headers.contentType = ContentType.json;
    if (corps != null) r.response.write(jsonEncode(corps));
    await r.response.close();
  }

  test('refresh token refusé : la requête échoue sans se bloquer et la session locale est effacée', () async {
    repondre = (r) => r.uri.path == ApiConfig.logout
        ? json(r, 204) // comme le backend : le logout répond 204 même pour un refresh token déjà invalide
        : json(r, 401, {'detail': 'Jeton expiré', 'code': 'NON_AUTHENTIFIE'});

    final appel = ApiClient.instance.get(ApiConfig.moi);
    await expectLater(
      appel.timeout(const Duration(seconds: 5)), // avant correctif : interblocage, jamais de réponse
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );

    expect(ApiClient.instance.estAuthentifie, isFalse);
    expect(AuthService.instance.profilActuel, isNull);
    expect(await SessionStorageService.instance.lireRefreshToken(), isNull);
    // Aucun appel authentifié (déconnexion serveur) n'est tenté avec un jeton refusé
    expect(requetes.where((q) => q.contains('/api/moi/deconnexion')), isEmpty);
  });

  test('un upload multipart rejoue avec le nouveau jeton après rafraîchissement', () async {
    repondre = (r) async {
      if (r.uri.path == ApiConfig.refresh) {
        return json(r, 200, {
          'jeton': 'jeton-neuf',
          'refreshToken': 'refresh-2',
          'profil': {'id': 7, 'type': 'COMMERCANT', 'nom': 'Awa', 'telephone': '+22373000001', 'statut': 'ACTIF'},
        });
      }
      await r.drain<void>();
      if (r.headers.value('authorization') == 'Bearer jeton-neuf') {
        return json(r, 200, {'photoUrl': '/api/public/images/avatars/avatar_7.jpg'});
      }
      return json(r, 401, {'detail': 'Jeton expiré'});
    };

    final reponse = await ApiClient.instance
        .postMultipart(ApiConfig.photoProfil, fileBytes: [0xFF, 0xD8, 0xFF], filename: 'a.jpg', fieldName: 'photo')
        .timeout(const Duration(seconds: 5));

    expect(reponse, {'photoUrl': '/api/public/images/avatars/avatar_7.jpg'});
    expect(requetes, [
      'POST /api/moi/photo Bearer jeton-expire',
      'POST /api/auth/refresh -',
      'POST /api/moi/photo Bearer jeton-neuf',
    ]);
    expect(await SessionStorageService.instance.lireRefreshToken(), 'refresh-2');
  });

  test('restaurerSession hors ligne conserve le refresh token pour le prochain lancement', () async {
    ApiConfig.baseUrlTest = 'http://127.0.0.1:1'; // port fermé : serveur injoignable

    expect(await AuthService.instance.restaurerSession(), isNull);
    expect(await SessionStorageService.instance.lireRefreshToken(), 'refresh-1');
  });
}
