import 'package:flutter/foundation.dart';
import '../commercant/campagne_model.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Service gérant les Groupes d'achat / Campagnes via l'API Backend DoGo
class GroupeApiService {
  GroupeApiService._();
  static final GroupeApiService instance = GroupeApiService._();

  /// Liste vide par défaut (aucune fausse donnée)
  static final List<GroupeCampagneModel> campagnesRepli = [];

  /// Récupère la liste des groupes d'achat ouverts (GET /api/groupes)
  Future<List<GroupeCampagneModel>> explorer({
    String? recherche,
    int? categorieId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (recherche != null && recherche.trim().isNotEmpty) {
        queryParams['q'] = recherche.trim();
      }
      if (categorieId != null) {
        queryParams['categorieId'] = categorieId;
      }

      final response = await ApiClient.instance.get(
        ApiConfig.groupes,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response is List) {
        return response
            .map((item) => GroupeCampagneModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('GroupeApiService.explorer - Erreur API : $e');
      return [];
    }
  }

  /// Récupère les détails d'un groupe spécifique (GET /api/groupes/{id})
  Future<GroupeCampagneModel> detail(dynamic id) async {
    final response = await ApiClient.instance.get(ApiConfig.groupeDetail(id));
    if (response is Map<String, dynamic>) {
      return GroupeCampagneModel.fromJson(response);
    }
    throw Exception('Groupe d\'achat introuvable');
  }

  /// Rejoindre un groupe d'achat (POST /api/groupes/{groupeId}/participations)
  Future<Map<String, dynamic>> rejoindreGroupe({
    required dynamic groupeId,
    required int varianteId,
    required int quantite,
  }) async {
    final response = await ApiClient.instance.post(
      ApiConfig.rejoindreGroupe(groupeId),
      body: {
        'varianteId': varianteId,
        'quantite': quantite,
      },
    );

    return response is Map<String, dynamic> ? response : {'participationId': 1};
  }
}
