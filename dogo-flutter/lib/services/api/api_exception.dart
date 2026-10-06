import 'dart:convert';

/// Exception standardisée pour l'API Backend DoGo, compatible RFC 7807 (ProblemDetail)
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final String? regle;
  final List<String> erreurs;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.regle,
    this.erreurs = const [],
  });

  /// Analyse une réponse JSON du backend (RFC 7807 ProblemDetail ou format standard)
  factory ApiException.fromResponseBody(int statusCode, String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'] as String? ??
            decoded['message'] as String? ??
            'Une erreur est survenue ($statusCode)';
        final code = decoded['code'] as String?;
        final regle = decoded['regle'] as String?;
        final erreursRaw = decoded['erreurs'];
        final List<String> erreurs = [];
        if (erreursRaw is List) {
          erreurs.addAll(erreursRaw.map((e) => e.toString()));
        }

        return ApiException(
          statusCode: statusCode,
          message: detail,
          code: code,
          regle: regle,
          erreurs: erreurs,
        );
      }
    } catch (_) {
      // Ignorer l'erreur de décodage JSON et utiliser le fallback ci-dessous
    }

    return ApiException(
      statusCode: statusCode,
      message: 'Erreur serveur ($statusCode). Veuillez réessayer.',
    );
  }

  /// Message utilisateur complet et lisible pour les SnackBars
  String get messageComplet {
    if (erreurs.isNotEmpty) {
      return '$message :\n• ${erreurs.join('\n• ')}';
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode, code: $code, message: $message)';
}
