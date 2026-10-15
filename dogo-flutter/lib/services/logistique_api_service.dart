import 'package:flutter/foundation.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Données du code de retrait selon RG-71 (CodeVue du backend)
class CodeRetraitDonnees {
  final int commandeId;

  /// Contenu du QR code : jeton unique généré par le backend, scanné au point de retrait
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
      commandeId: (json['commandeId'] as num).toInt(),
      qrToken: json['qrToken'] as String,
      expiration: json['expiration']?.toString() ?? '',
      tentativesRestantes: (json['tentativesRestantes'] as num?)?.toInt() ?? 3,
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

  /// Commandes prêtes à être retirées (statut EN_ATTENTE_RETRAIT) : ce sont les seules qui ont un code
  Future<List<Map<String, dynamic>>> commandesARetirer() async {
    final commandes = await mesCommandes();
    return commandes.where((c) => c['statut'] == 'EN_ATTENTE_RETRAIT').toList();
  }

  /// Jeton du QR code de retrait (GET /api/commandes/{id}/code-retrait). Aucun jeton de repli : un code
  /// inventé ne serait jamais accepté au point de retrait, l'erreur est donc remontée à l'écran.
  Future<CodeRetraitDonnees> obtenirCodeRetrait(dynamic commandeId) async {
    final response = await ApiClient.instance.get(ApiConfig.codeRetrait(commandeId));
    if (response is Map<String, dynamic>) {
      return CodeRetraitDonnees.fromJson(response);
    }
    throw Exception('Format de code retrait invalide');
  }

  /// Validation du retrait par le courtier (POST /api/retraits/valider, RG-53) :
  /// soit le contenu du QR code scanné, soit le numéro de commande avec le PIN reçu par SMS.
  Future<Map<String, dynamic>> validerRetrait({
    dynamic commandeId,
    String? qrToken,
    String? pin,
  }) async {
    final response = await ApiClient.instance.post(
      ApiConfig.validerRetrait,
      body: {
        if (qrToken != null) 'qrToken': qrToken,
        if (qrToken == null && commandeId != null) 'commandeId': commandeId,
        if (qrToken == null && pin != null) 'pin': pin,
      },
    );

    return response is Map<String, dynamic> ? response : {'statut': 'COLLECTEE'};
  }
}
