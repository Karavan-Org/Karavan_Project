import 'package:flutter/foundation.dart';
import '../models/utilisateur_profil.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'session_storage_service.dart';

export '../models/utilisateur_profil.dart';

/// Service d'Authentification gérant les sessions, JWT et profils
class AuthService {
  AuthService._() {
    ApiClient.instance.onRefreshRequired = rafraichirJeton;
  }
  static final AuthService instance = AuthService._();

  final ValueNotifier<UtilisateurProfil?> profilNotifier = ValueNotifier<UtilisateurProfil?>(null);

  UtilisateurProfil? get profilActuel => profilNotifier.value;
  UtilisateurProfil? get utilisateurCourant => profilNotifier.value;
  bool get estConnecte => profilNotifier.value != null && ApiClient.instance.estAuthentifie;

  /// Restaure la session au démarrage à partir de flutter_secure_storage
  Future<UtilisateurProfil?> restaurerSession() async {
    final refreshToken = await SessionStorageService.instance.lireRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await ApiClient.instance.postSansAuth(
        ApiConfig.refresh,
        body: {'refreshToken': refreshToken},
      );

      if (response is Map<String, dynamic>) {
        final jeton = response['jeton'] as String?;
        final nouveauRefreshToken = response['refreshToken'] as String?;
        final profilJson = response['profil'] as Map<String, dynamic>? ?? {};
        final profil = UtilisateurProfil.fromJson(profilJson);

        ApiClient.instance.definirJeton(jeton);
        profilNotifier.value = profil;

        if (nouveauRefreshToken != null && nouveauRefreshToken.isNotEmpty) {
          await SessionStorageService.instance.sauvegarderSession(
            refreshToken: nouveauRefreshToken,
            profil: profil,
          );
        }
        return profil;
      }
    } catch (_) {
      // Session expirée ou révoquée sur le serveur
      await SessionStorageService.instance.effacerSession();
      ApiClient.instance.deconnecter();
      profilNotifier.value = null;
    }
    return null;
  }

  /// Rafraîchissement automatique de l'access token sur interception 401
  Future<bool> rafraichirJeton() async {
    final refreshToken = await SessionStorageService.instance.lireRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await ApiClient.instance.postSansAuth(
        ApiConfig.refresh,
        body: {'refreshToken': refreshToken},
      );

      if (response is Map<String, dynamic>) {
        final jeton = response['jeton'] as String?;
        final nouveauRefreshToken = response['refreshToken'] as String?;
        final profilJson = response['profil'] as Map<String, dynamic>?;

        ApiClient.instance.definirJeton(jeton);
        if (profilJson != null) {
          final profil = UtilisateurProfil.fromJson(profilJson);
          profilNotifier.value = profil;
          if (nouveauRefreshToken != null && nouveauRefreshToken.isNotEmpty) {
            await SessionStorageService.instance.sauvegarderSession(
              refreshToken: nouveauRefreshToken,
              profil: profil,
            );
          }
        }
        return true;
      }
    } catch (_) {
      await deconnecter();
    }
    return false;
  }

  /// Connexion par téléphone et mot de passe (RG-07)
  Future<UtilisateurProfil> connecter({
    required String telephone,
    String? motDePasse,
    String? pin,
    String? deviceId,
  }) async {
    final secret = (motDePasse != null && motDePasse.isNotEmpty) ? motDePasse : (pin ?? '');
    try {
      final response = await ApiClient.instance.post(
        ApiConfig.connexion,
        body: {
          'telephone': telephone,
          'motDePasse': secret,
          'pin': secret,
          'deviceId': deviceId ?? 'flutter-device-client',
        },
      );

      if (response is Map<String, dynamic>) {
        final jeton = response['jeton'] as String?;
        ApiClient.instance.definirJeton(jeton);

        final profilJson = response['profil'] as Map<String, dynamic>? ?? {};
        final profil = UtilisateurProfil.fromJson(profilJson);
        profilNotifier.value = profil;

        final refreshToken = response['refreshToken'] as String?;
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await SessionStorageService.instance.sauvegarderSession(
            refreshToken: refreshToken,
            profil: profil,
          );
        }

        return profil;
      }

      throw Exception('Format de réponse serveur inattendu');
    } catch (e) {
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
    String? motDePasse,
    String? pin,
    String? nomBoutique,
    String? quartierBamako,
    String? numeroNif,
    String? nomBoutiqueMarche,
    String? registreCommerce,
    String? nomSocieteImport,
    String? licenceTransit,
    String? adresseDepot,
  }) async {
    final secret = (motDePasse != null && motDePasse.isNotEmpty) ? motDePasse : (pin ?? '');
    final body = {
      'type': typeActeur.toUpperCase(),
      'telephone': telephone,
      'nom': nom,
      'motDePasse': secret,
      'pin': secret,
      if (nomBoutique != null) 'nomBoutique': nomBoutique,
      if (quartierBamako != null) 'quartierBamako': quartierBamako,
      if (numeroNif != null) 'numeroNif': numeroNif,
      if (nomBoutiqueMarche != null) 'nomBoutiqueMarche': nomBoutiqueMarche,
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

  /// Demande le renvoi d'un nouveau code OTP par SMS (RG-02)
  Future<Map<String, dynamic>> renvoyerOtp({
    required String telephone,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiConfig.renvoyerOtp,
        body: {
          'telephone': telephone,
        },
      );
      return response is Map<String, dynamic> ? response : {};
    } catch (e) {
      if (kDebugMode && e.toString().contains('Impossible de joindre le serveur')) {
        return {'statut': 'EN_ATTENTE_VERIFICATION', 'codeOtp': '1234'};
      }
      rethrow;
    }
  }

  /// Upload d'une photo de profil (JPEG, PNG, WEBP) vers le serveur (stockage sécurisé)
  Future<String> uploaderPhotoProfil(Uint8List octets, {String nom = 'avatar.jpg'}) async {
    try {
      final response = await ApiClient.instance.postMultipart(
        ApiConfig.photoProfil,
        fileBytes: octets,
        filename: nom,
        fieldName: 'photo',
      );

      String photoUrl = '';
      if (response is Map<String, dynamic>) {
        photoUrl = response['photoUrl'] as String? ?? '';
      } else if (response is String) {
        photoUrl = response;
      }

      if (photoUrl.isNotEmpty && profilActuel != null) {
        final maj = profilActuel!.copyWith(photoUrl: photoUrl);
        profilNotifier.value = maj;
        await SessionStorageService.instance.sauvegarderProfil(maj);
      }
      return photoUrl;
    } catch (e) {
      if (kDebugMode && e.toString().contains('Impossible de joindre le serveur')) {
        // Mode hors-ligne / fallback
        if (profilActuel != null) {
          final maj = profilActuel!.copyWith(photoUrl: '/api/public/images/avatars/mock_avatar.jpg');
          profilNotifier.value = maj;
          return maj.photoUrl!;
        }
      }
      rethrow;
    }
  }

  /// Supprime la photo de profil personnalisée
  Future<void> supprimerPhotoProfil() async {
    try {
      await ApiClient.instance.patch(
        ApiConfig.moi,
        body: {'photoUrl': ''},
      );
      if (profilActuel != null) {
        final maj = UtilisateurProfil(
          id: profilActuel!.id,
          type: profilActuel!.type,
          nom: profilActuel!.nom,
          telephone: profilActuel!.telephone,
          photoUrl: null,
          statut: profilActuel!.statut,
          permissions: profilActuel!.permissions,
        );
        profilNotifier.value = maj;
        await SessionStorageService.instance.sauvegarderProfil(maj);
      }
    } catch (e) {
      if (kDebugMode && e.toString().contains('Impossible de joindre le serveur')) {
        if (profilActuel != null) {
          final maj = UtilisateurProfil(
            id: profilActuel!.id,
            type: profilActuel!.type,
            nom: profilActuel!.nom,
            telephone: profilActuel!.telephone,
            photoUrl: null,
            statut: profilActuel!.statut,
            permissions: profilActuel!.permissions,
          );
          profilNotifier.value = maj;
        }
        return;
      }
      rethrow;
    }
  }

  /// Recharge le profil depuis le serveur (synchronise toutes les informations fraîches)
  Future<UtilisateurProfil?> rechargerProfil() async {
    if (!ApiClient.instance.estAuthentifie) return profilActuel;
    try {
      final response = await ApiClient.instance.get(ApiConfig.moi);
      if (response is Map<String, dynamic>) {
        final nouveau = UtilisateurProfil.fromJson(response);
        final maj = (profilActuel != null)
            ? profilActuel!.copyWith(
                id: nouveau.id,
                nom: nouveau.nom.isNotEmpty ? nouveau.nom : profilActuel!.nom,
                telephone: nouveau.telephone.isNotEmpty ? nouveau.telephone : profilActuel!.telephone,
                photoUrl: nouveau.photoUrl,
                statut: nouveau.statut,
                nomStructure: nouveau.nomStructure ?? profilActuel!.nomStructure,
                quartier: nouveau.quartier ?? profilActuel!.quartier,
              )
            : nouveau;

        profilNotifier.value = maj;
        await SessionStorageService.instance.sauvegarderProfil(maj);
        return maj;
      }
    } catch (_) {}
    return profilActuel;
  }

  /// Modification du mot de passe utilisateur (RG-07)
  Future<void> changerMotDePasse({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) async {
    await ApiClient.instance.post(
      ApiConfig.changerMotDePasse,
      body: {
        'ancienMotDePasse': ancienMotDePasse,
        'nouveauMotDePasse': nouveauMotDePasse,
      },
    );
  }

  /// Déconnexion révoquant le refresh token côté serveur et effaçant le stockage sécurisé
  Future<void> deconnecter() async {
    final rt = await SessionStorageService.instance.lireRefreshToken();
    try {
      if (rt != null && rt.isNotEmpty) {
        await ApiClient.instance.postSansAuth(ApiConfig.logout, body: {'refreshToken': rt});
      }
      if (ApiClient.instance.estAuthentifie) {
        await ApiClient.instance.post(ApiConfig.deconnexion, body: {});
      }
    } catch (_) {}
    await SessionStorageService.instance.effacerSession();
    ApiClient.instance.deconnecter();
    profilNotifier.value = null;
  }
}
