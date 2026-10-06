import 'package:flutter/foundation.dart';
import '../models/role_acteur.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Profil de l'utilisateur connecté selon le contrat Spring Boot (ml.dogo.identite)
class UtilisateurProfil {
  final int id;
  final String type; // COMMERCANT, GROSSISTE, COURTIER, ADMINISTRATEUR
  final String nom;
  final String telephone;
  final String statut;
  final List<String> permissions;

  const UtilisateurProfil({
    required this.id,
    required this.type,
    required this.nom,
    required this.telephone,
    required this.statut,
    this.permissions = const [],
  });

  factory UtilisateurProfil.fromJson(Map<String, dynamic> json) {
    return UtilisateurProfil(
      id: json['id'] as int? ?? 1,
      type: json['type'] as String? ?? 'COMMERCANT',
      nom: json['nom'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      statut: json['statut'] as String? ?? 'ACTIF',
      permissions: (json['permissions'] as List<dynamic>?)?.map((p) => p.toString()).toList() ?? [],
    );
  }

  String get nomComplet => nom;
  String? get structure => null;

  RoleActeur get roleActeur {
    switch (type.toUpperCase()) {
      case 'GROSSISTE':
        return RoleActeur.grossiste;
      case 'COURTIER':
        return RoleActeur.courtier;
      case 'COMMERCANT':
      default:
        return RoleActeur.commercant;
    }
  }
}

/// Service d'Authentification gérant les sessions, JWT et profils
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final ValueNotifier<UtilisateurProfil?> profilNotifier = ValueNotifier<UtilisateurProfil?>(null);

  UtilisateurProfil? get profilActuel => profilNotifier.value;
  UtilisateurProfil? get utilisateurCourant => profilNotifier.value;
  bool get estConnecte => profilNotifier.value != null && ApiClient.instance.estAuthentifie;

  /// Connexion par téléphone et PIN secret (RG-07)
  Future<UtilisateurProfil> connecter({
    required String telephone,
    required String pin,
    String? deviceId,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiConfig.connexion,
        body: {
          'telephone': telephone,
          'pin': pin,
          'deviceId': deviceId ?? 'flutter-device-client',
        },
      );

      if (response is Map<String, dynamic>) {
        final jeton = response['jeton'] as String?;
        ApiClient.instance.definirJeton(jeton);

        final profilJson = response['profil'] as Map<String, dynamic>? ?? {};
        final profil = UtilisateurProfil.fromJson(profilJson);
        profilNotifier.value = profil;
        return profil;
      }

      throw Exception('Format de réponse serveur inattendu');
    } catch (e) {
      // Si le serveur est injoignable en mode démo / développement, repli gracieux
      if (kDebugMode && e.toString().contains('Impossible de joindre le serveur')) {
        final profilFactice = UtilisateurProfil(
          id: 1,
          type: 'COMMERCANT',
          nom: 'Commerçant Démo Bamako',
          telephone: telephone,
          statut: 'ACTIF',
        );
        profilNotifier.value = profilFactice;
        ApiClient.instance.definirJeton('demo-mock-jwt-token');
        return profilFactice;
      }
      rethrow;
    }
  }

  /// Inscription d'un nouvel utilisateur selon son rôle (RG-01 à RG-03)
  Future<Map<String, dynamic>> inscrire({
    required String typeActeur, // COMMERCANT, GROSSISTE, COURTIER
    required String telephone,
    required String nom,
    required String pin,
    String? nomBoutique,
    String? quartierBamako,
    String? numeroNif,
    String? registreCommerce,
    String? nomSocieteImport,
    String? licenceTransit,
    String? adresseDepot,
  }) async {
    final body = {
      'type': typeActeur.toUpperCase(),
      'telephone': telephone,
      'nom': nom,
      'pin': pin,
      if (nomBoutique != null) 'nomBoutique': nomBoutique,
      if (quartierBamako != null) 'quartierBamako': quartierBamako,
      if (numeroNif != null) 'numeroNif': numeroNif,
      if (registreCommerce != null) 'registreCommerce': registreCommerce,
      if (nomSocieteImport != null) 'nomSocieteImport': nomSocieteImport,
      if (licenceTransit != null) 'licenceTransit': licenceTransit,
      if (adresseDepot != null) 'adresseDepot': adresseDepot,
    };

    try {
      final response = await ApiClient.instance.post(ApiConfig.inscription, body: body);
      return response is Map<String, dynamic> ? response : {};
    } catch (e) {
      if (kDebugMode && e.toString().contains('Impossible de joindre le serveur')) {
        return {'statut': 'ATTENTE_OTP', 'telephone': telephone};
      }
      rethrow;
    }
  }

  /// Vérification de l'OTP reçu par SMS (RG-02)
  Future<Map<String, dynamic>> verifierOtp({
    required String telephone,
    required String code,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiConfig.verifierOtp,
        body: {
          'telephone': telephone,
          'code': code,
        },
      );
      return response is Map<String, dynamic> ? response : {};
    } catch (e) {
      if (kDebugMode && e.toString().contains('Impossible de joindre le serveur')) {
        return {'statut': 'ACTIF'};
      }
      rethrow;
    }
  }

  /// Déconnexion
  void deconnecter() {
    ApiClient.instance.deconnecter();
    profilNotifier.value = null;
  }
}
