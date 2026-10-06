import 'dart:typed_data';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Service API pour la gestion du Catalogue Grossiste et l'upload des photos de produits
class CatalogueApiService {
  CatalogueApiService._();
  static final CatalogueApiService instance = CatalogueApiService._();

  final ApiClient _api = ApiClient.instance;

  /// Téléverse une photo de produit sur le serveur Spring Boot via multipart/form-data
  /// Retourne l'URL relative de la photo stockée (ex: /api/public/images/produits/prod_1_uuid.jpg)
  Future<String> uploaderPhotoProduit({
    required Uint8List bytes,
    required String nomFichier,
  }) async {
    final response = await _api.postMultipart(
      ApiConfig.catalogueUploadPhoto,
      fileBytes: bytes,
      filename: nomFichier,
      fieldName: 'photo',
    );

    if (response is Map && response.containsKey('photoUrl')) {
      return response['photoUrl'] as String;
    }
    throw Exception("Réponse inattendue du serveur lors de l'upload de la photo.");
  }

  /// Crée un nouveau produit dans le catalogue avec sa photo et ses variantes
  Future<Map<String, dynamic>> creerProduit({
    required int categorieId,
    required String nom,
    String? description,
    String? paysOrigine,
    String? photoUrl,
    required List<Map<String, dynamic>> variantes,
  }) async {
    final body = {
      'categorieId': categorieId,
      'nom': nom,
      'description': description,
      'paysOrigine': paysOrigine,
      'photoUrl': photoUrl,
      'variantes': variantes,
    };

    final response = await _api.post(
      ApiConfig.catalogueProduits,
      body: body,
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Récupère la liste des produits du Grossiste connecté
  Future<List<dynamic>> mesProduits() async {
    final response = await _api.get(ApiConfig.catalogueProduits);
    if (response is List) {
      return response;
    }
    return [];
  }

  /// Récupère la liste des catégories disponibles
  Future<List<dynamic>> categories() async {
    final response = await _api.get(ApiConfig.catalogueCategories);
    if (response is List) {
      return response;
    }
    return [];
  }
}

