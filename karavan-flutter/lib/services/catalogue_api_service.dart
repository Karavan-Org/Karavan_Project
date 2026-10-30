import 'package:flutter/foundation.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Service API pour la gestion du Catalogue Grossiste et l'upload des photos de produits
class CatalogueApiService {
  CatalogueApiService._();
  static final CatalogueApiService instance = CatalogueApiService._();

  final ApiClient _api = ApiClient.instance;

  /// Incrémenté à chaque changement du catalogue ou des groupes du grossiste :
  /// l'accueil et l'onglet Catalogue l'écoutent pour se recharger.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void signalerChangement() => revision.value++;

  /// Stock total d'un produit (somme des variantes)
  static int stockTotal(Map p) =>
      ((p['variantes'] as List?) ?? []).fold<int>(0, (t, v) => t + (((v as Map)['qteDisponible'] as num?) ?? 0).toInt());

  /// Le SKU est unique sur toute la plateforme (RG-12) : préfixe tiré du nom, horodatage, rang de la variante.
  static List<String> genererSkus(String nomProduit, int nombre) {
    final prefixe = nomProduit.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').padRight(3, 'X').substring(0, 3);
    final horodatage = DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();
    return List.generate(nombre, (i) => '$prefixe-$horodatage-${i + 1}');
  }

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
    num? prixGros,
    required List<Map<String, dynamic>> variantes,
  }) async {
    final body = {
      'categorieId': categorieId,
      'nom': nom,
      'description': description,
      'paysOrigine': paysOrigine,
      'photoUrl': photoUrl,
      if (prixGros != null && prixGros > 0) 'prixGros': prixGros,
      'variantes': variantes,
    };

    final response = await _api.post(
      ApiConfig.catalogueProduits,
      body: body,
    );

    signalerChangement();
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

