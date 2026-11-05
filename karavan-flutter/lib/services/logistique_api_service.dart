import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Données du code de retrait selon RG-71 (CodeVue du backend)
class CodeRetraitDonnees {
  final int commandeId;

  /// Contenu du QR code : jeton unique opaque généré par le backend, scanné au point de retrait
  final String qrToken;
  final String? codeCourt;
  final String expiration;
  final int tentativesRestantes;
  final bool bloque;

  const CodeRetraitDonnees({
    required this.commandeId,
    required this.qrToken,
    this.codeCourt,
    required this.expiration,
    this.tentativesRestantes = 3,
    this.bloque = false,
  });

  factory CodeRetraitDonnees.fromJson(Map<String, dynamic> json) {
    return CodeRetraitDonnees(
      commandeId: (json['commandeId'] as num).toInt(),
      qrToken: json['qrToken'] as String,
      codeCourt: json['codeCourt'] as String?,
      expiration: json['expiration']?.toString() ?? '',
      tentativesRestantes: (json['tentativesRestantes'] as num?)?.toInt() ?? 3,
      bloque: json['bloque'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'commandeId': commandeId,
    'qrToken': qrToken,
    if (codeCourt != null) 'codeCourt': codeCourt,
    'expiration': expiration,
    'tentativesRestantes': tentativesRestantes,
    'bloque': bloque,
  };
}

/// Service de suivi logistique, acheminement et retraits (RG-44 à RG-56)
class LogistiqueApiService {
  LogistiqueApiService._();
  static final LogistiqueApiService instance = LogistiqueApiService._();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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

  /// Récupère la liste des participations de l'utilisateur (GET /api/moi/participations)
  Future<List<Map<String, dynamic>>> mesParticipations() async {
    try {
      final response = await ApiClient.instance.get(ApiConfig.mesParticipations);
      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('LogistiqueApiService.mesParticipations - Repli local : $e');
      return [];
    }
  }

  /// Récupère la liste des convois actifs (GET /api/convois)
  Future<List<Map<String, dynamic>>> convois() async {
    try {
      final response = await ApiClient.instance.get(ApiConfig.convois);
      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('LogistiqueApiService.convois - Repli local : $e');
      return [];
    }
  }

  /// Commandes prêtes à être retirées (statut EN_ATTENTE_RETRAIT) : ce sont les seules qui ont un code
  Future<List<Map<String, dynamic>>> commandesARetirer() async {
    final commandes = await mesCommandes();
    return commandes.where((c) => c['statut'] == 'EN_ATTENTE_RETRAIT').toList();
  }

  /// Jeton du QR code de retrait (GET /api/commandes/{id}/code-retrait).
  /// Mise en cache sécurisée locale pour affichage hors réseau si connexion indisponible.
  Future<CodeRetraitDonnees> obtenirCodeRetrait(dynamic commandeId) async {
    final cacheKey = 'code_retrait_$commandeId';
    try {
      final response = await ApiClient.instance.get(ApiConfig.codeRetrait(commandeId));
      if (response is Map<String, dynamic>) {
        final code = CodeRetraitDonnees.fromJson(response);
        await _storage.write(key: cacheKey, value: jsonEncode(code.toJson()));
        return code;
      }
      throw Exception('Format de code retrait invalide');
    } catch (e) {
      // Repli cache hors ligne si le réseau n'est pas disponible
      final cachedJson = await _storage.read(key: cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final map = jsonDecode(cachedJson) as Map<String, dynamic>;
          debugPrint('LogistiqueApiService : Code de retrait chargé depuis le cache hors-ligne pour la commande #$commandeId');
          return CodeRetraitDonnees.fromJson(map);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Régénération du code de retrait pour une commande expirée ou bloquée (POST /api/commandes/{id}/code-retrait/regeneration)
  Future<CodeRetraitDonnees> regenererCodeRetrait(dynamic commandeId) async {
    final response = await ApiClient.instance.post(ApiConfig.regenererCodeRetrait(commandeId));
    if (response is Map<String, dynamic>) {
      final code = CodeRetraitDonnees.fromJson(response);
      final cacheKey = 'code_retrait_$commandeId';
      await _storage.write(key: cacheKey, value: jsonEncode(code.toJson()));
      return code;
    }
    throw Exception('Impossible de régénérer le code');
  }

  /// Validation du retrait par l'agent ou courtier (POST /api/retraits/valider, RG-53 à RG-56)
  Future<Map<String, dynamic>> validerRetrait({
    dynamic commandeId,
    String? qrToken,
    String? pin,
    String? codeCourt,
  }) async {
    final response = await ApiClient.instance.post(
      ApiConfig.validerRetrait,
      body: {
        if (qrToken != null) 'qrToken': qrToken,
        if (qrToken == null && commandeId != null) 'commandeId': commandeId,
        if (qrToken == null && pin != null) 'pin': pin,
        if (qrToken == null && codeCourt != null) 'codeCourt': codeCourt,
      },
    );

    return response is Map<String, dynamic> ? response : {'statut': 'COLLECTEE'};
  }

  /// Validation de l'arrivée d'un colis par scan du QR colis ou saisie du code court (POST /api/colis/valider-arrivee)
  Future<Map<String, dynamic>> validerArriveeColis({
    required String jetonOuCodeCourt,
  }) async {
    final response = await ApiClient.instance.post(
      ApiConfig.validerArriveeColis,
      body: {
        'jeton': jetonOuCodeCourt,
      },
    );

    return response is Map<String, dynamic> ? response : {'statut': 'ARRIVE'};
  }
}
