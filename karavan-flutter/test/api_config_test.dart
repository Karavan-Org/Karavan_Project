import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/services/api/api_config.dart';

void main() {
  test('ApiConfig.baseUrl fournit une URL valide et cohérente', () {
    expect(ApiConfig.baseUrl, isNotEmpty);
    expect(ApiConfig.baseUrl.startsWith('http://') || ApiConfig.baseUrl.startsWith('https://'), isTrue);
    expect(ApiConfig.baseUrl.endsWith('/'), isFalse);

    // Test de résolution d'image
    final imageUrl = ApiConfig.resolutionImageUrl('/api/public/images/produits/test.jpg');
    expect(imageUrl, startsWith(ApiConfig.baseUrl));
    expect(imageUrl.endsWith('/api/public/images/produits/test.jpg'), isTrue);
  });

  test('ApiConfig configure correctement les paramètres Google Sign-In', () {
    expect(ApiConfig.googleClientId, equals('462534787008-7c48fkvh3n0nu65po72p005qr5qo05ot.apps.googleusercontent.com'));
    expect(ApiConfig.googleAuth, equals('/api/auth/google'));
    expect(ApiConfig.googleCompleter, equals('/api/auth/google/completer'));
    expect(ApiConfig.googleDemanderOtp, equals('/api/auth/google/demander-otp'));
  });
}

