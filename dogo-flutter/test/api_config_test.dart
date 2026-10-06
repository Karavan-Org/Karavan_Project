import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/services/api/api_config.dart';

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
}

