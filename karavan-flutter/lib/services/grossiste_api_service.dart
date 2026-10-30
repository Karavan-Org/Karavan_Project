import '../models/campagne_model.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Service des groupes vus par le Grossiste : validation de disponibilité (RG-18) et suivi des lots vendus
class GrossisteApiService {
  GrossisteApiService._();
  static final GrossisteApiService instance = GrossisteApiService._();

  final ApiClient _api = ApiClient.instance;

  static List<Map<String, dynamic>> _liste(dynamic response) =>
      response is List ? response.whereType<Map<String, dynamic>>().toList() : const [];

  /// GET /api/groupes/a-valider : groupes EN_VALIDATION qui attendent la confirmation du stock
  Future<List<GroupeCampagneModel>> groupesAValider() async =>
      _liste(await _api.get(ApiConfig.groupesAValider)).map(GroupeCampagneModel.fromJson).toList();

  /// GET /api/groupes/du-grossiste : tous les groupes montés sur les produits du grossiste
  Future<List<GroupeCampagneModel>> mesGroupes() async =>
      _liste(await _api.get(ApiConfig.groupesDuGrossiste)).map(GroupeCampagneModel.fromJson).toList();

  /// POST /api/groupes/{id}/disponibilite (refusé si le stock total est inférieur à la cible, RG-13)
  Future<GroupeCampagneModel> validerDisponibilite(String groupeId) async {
    final response = await _api.post(ApiConfig.disponibiliteGroupe(groupeId));
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Format de réponse serveur inattendu');
    }
    return GroupeCampagneModel.fromJson(response);
  }

  /// GET /api/groupes/{id}/commandes (sans l'identité des acheteurs, RG-71)
  Future<List<Map<String, dynamic>>> commandesDuGroupe(String groupeId) async =>
      _liste(await _api.get(ApiConfig.commandesDuGroupe(groupeId)));
}
