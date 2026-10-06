import 'package:flutter/foundation.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Données du code de retrait selon RG-71
class CodeRetraitDonnees {
  final int commandeId;
  final String qrToken;
  final String expiration;
  final int tentativesRestantes;
  final bool bloque;

  const CodeRetraitDonnees({
    required this.commandeId,
    required this.qrToken,
    required this.expiration,
    this.tentativesRestantes = 3,
    this.bloque = false,
  });

  factory CodeRetraitDonnees.fromJson(Map<String, dynamic> json) {
    return CodeRetraitDonnees(
      commandeId: json['commandeId'] as int? ?? 1,
      qrToken: json['qrToken'] as String? ?? 'DOGO-RETRAIT-TOKEN-DEMO',
      expiration: json['expiration']?.toString() ?? '',
      tentativesRestantes: json['tentativesRestantes'] as int? ?? 3,
      bloque: json['bloque'] as bool? ?? false,
    );
  }
}

/// Service de suivi logistique, acheminement et retraits (RG-44 à RG-56)
class LogistiqueApiService {
  LogistiqueApiService._();
  static final LogistiqueApiService instance = LogistiqueApiService._();

  /// Récupère la liste des commandes de l'utilisateur (GET /api/moi/commandes)
  Future<List<Map<String, dynamic>>> mesCommandes() async {
    try {
      final response = await ApiClient.instance.get(ApiConfig.mesCommandes);
      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('LogistiqueApiService.mesCommandes - Repli local : $e');
      return [];
    }
  }

  /// Récupère le jeton sécurisé QR Code pour le retrait (GET /api/commandes/{id}/code-retrait)
  Future<CodeRetraitDonnees> obtenirCodeRetrait(dynamic commandeId) async {
    try {
      final response = await ApiClient.instance.get(ApiConfig.codeRetrait(commandeId));
      if (response is Map<String, dynamic>) {
        return CodeRetraitDonnees.fromJson(response);
      }
      throw Exception('Format de code retrait invalide');
    } catch (e) {
      debugPrint('LogistiqueApiService.obtenirCodeRetrait - Repli mode démo : $e');
      return CodeRetraitDonnees(
        commandeId: int.tryParse(commandeId.toString()) ?? 1,
        qrToken: 'DOGO-TOKEN-BKO-${commandeId.toString()}-SECURE',
        expiration: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      );
    }
  }

  /// Validation du retrait par le courtier / magasinier (POST /api/retraits/valider)
  Future<Map<String, dynamic>> validerRetrait({
    dynamic commandeId,
    String? qrToken,
    required String pin,
  }) async {
    final response = await ApiClient.instance.post(
      ApiConfig.validerRetrait,
      body: {
        if (commandeId != null) 'commandeId': commandeId,
        if (qrToken != null) 'qrToken': qrToken,
        'pin': pin,
      },
    );

    return response is Map<String, dynamic> ? response : {'statut': 'LIVRE'};
  }
}
