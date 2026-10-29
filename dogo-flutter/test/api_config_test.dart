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
    expect(ApiConfig.googleClientId, equals('462534787008-glu9glf6979ldlth5dc2g9l6sjmnboah.apps.googleusercontent.com'));
    expect(ApiConfig.googleAuth, equals('/api/auth/google'));
    expect(ApiConfig.googleCompleter, equals('/api/auth/google/completer'));
    expect(ApiConfig.googleDemanderOtp, equals('/api/auth/google/demander-otp'));
  });
}

