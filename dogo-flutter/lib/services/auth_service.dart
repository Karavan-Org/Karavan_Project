import 'package:flutter/foundation.dart';
import '../models/utilisateur_profil.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import 'session_storage_service.dart';

export '../models/utilisateur_profil.dart';

/// Service d'Authentification gérant les sessions, JWT et profils
class AuthService {
  AuthService._() {
    ApiClient.instance.onRefreshRequired = rafraichirJeton;
  }
  static final AuthService instance = AuthService._();

  final ValueNotifier<UtilisateurProfil?> profilNotifier =
      ValueNotifier<UtilisateurProfil?>(null);

  UtilisateurProfil? get profilActuel => profilNotifier.value;
  UtilisateurProfil? get utilisateurCourant => profilNotifier.value;
  bool get estConnecte =>
      profilNotifier.value != null && ApiClient.instance.estAuthentifie;

  Map<String, String> get _entetesPlateforme =>
      kIsWeb ? const {'X-Client-Platform': 'flutter-web'} : const {};

  /// Restaure la session au démarrage à partir de flutter_secure_storage ou retour Auth0 URL
  Future<UtilisateurProfil?> restaurerSession() async {
    // 0. Détection d'un retour d'authentification Auth0 via l'URL Web (fragment hash #id_token=... ou query param)
    if (kIsWeb) {
      final uri = Uri.base;
      String? idToken = uri.queryParameters['id_token'];
      if ((idToken == null || idToken.isEmpty) && uri.fragment.isNotEmpty) {
        final frag = Uri.splitQueryString(uri.fragment.replaceFirst(RegExp(r'^/?'), ''));
        idToken = frag['id_token'];
      }
      if (idToken != null && idToken.isNotEmpty) {
        try {
          final res = await authentifierAuth0(idToken);
          if (res['statut'] == 'CONNECTE' && res['profil'] is UtilisateurProfil) {
            return res['profil'] as UtilisateurProfil;
          }
        } catch (_) {}
      }
    }

    final refreshToken =
        kIsWeb ? null : await SessionStorageService.instance.lireRefreshToken();
    if (!kIsWeb && (refreshToken == null || refreshToken.isEmpty)) {
      return null;
    }

    try {
      final response = await ApiClient.instance.postSansAuth(
        ApiConfig.refresh,
        body: kIsWeb ? null : {'refreshToken': refreshToken},
        headers: _entetesPlateforme,
      );

      if (response is Map<String, dynamic>) {
        final jeton = response['jeton'] as String?;
        final nouveauRefreshToken = response['refreshToken'] as String?;
        final profilJson = response['profil'] as Map<String, dynamic>? ?? {};
        final profil = UtilisateurProfil.fromJson(profilJson);

        ApiClient.instance.definirJeton(jeton);
        profilNotifier.value = profil;

        await SessionStorageService.instance.sauvegarderSession(
          refreshToken: nouveauRefreshToken ?? '',
          profil: profil,
        );
        return profil;
      }
    } on ApiException catch (e) {
      // Session expirée ou révoquée sur le serveur. Sans réseau (statusCode 0), on garde le
      // refresh token : la session sera restaurée au prochain lancement avec connexion.
      if (e.statusCode != 0) {
        await _effacerSessionLocale();
      }
    } catch (_) {
      await _effacerSessionLocale();
    }
    return null;
  }

  /// Oublie la session sur cet appareil, sans appel réseau.
  Future<void> _effacerSessionLocale() async {
    await SessionStorageService.instance.effacerSession();
    ApiClient.instance.deconnecter();
    profilNotifier.value = null;
  }

  /// Rafraîchissement automatique de l'access token sur interception 401
  Future<bool> rafraichirJeton() async {
    final refreshToken =
        kIsWeb ? null : await SessionStorageService.instance.lireRefreshToken();
    if (!kIsWeb && (refreshToken == null || refreshToken.isEmpty)) {
      return false;
    }

    try {
      final response = await ApiClient.instance.postSansAuth(
        ApiConfig.refresh,
        body: kIsWeb ? null : {'refreshToken': refreshToken},
        headers: _entetesPlateforme,
      );

      if (response is Map<String, dynamic>) {
        final jeton = response['jeton'] as String?;
        final nouveauRefreshToken = response['refreshToken'] as String?;
        final profilJson = response['profil'] as Map<String, dynamic>?;

        ApiClient.instance.definirJeton(jeton);
        if (profilJson != null) {
          final profil = UtilisateurProfil.fromJson(profilJson);
          profilNotifier.value = profil;
          await SessionStorageService.instance.sauvegarderSession(
            refreshToken: nouveauRefreshToken ?? '',
            profil: profil,
          );
        }
        return true;
      }
    } on ApiException catch (e) {
      // Refresh token refusé : la session est terminée. Surtout pas deconnecter() ici : ses appels
      // authentifiés recevraient un 401 et attendraient ce même rafraîchissement (interblocage).
      if (e.statusCode != 0) {
        await _effacerSessionLocale();
      }
    } catch (_) {
      await _effacerSessionLocale();
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
    final secret = (motDePasse != null && motDePasse.isNotEmpty)
        ? motDePasse
        : (pin ?? '');
    final response = await ApiClient.instance.post(
      ApiConfig.connexion,
      body: {
        'telephone': telephone,
        'motDePasse': secret,
        'pin': secret,
        'deviceId': deviceId ?? 'flutter-device-client',
      },
      headers: _entetesPlateforme,
    );

    if (response is! Map<String, dynamic> || response['jeton'] is! String) {
      throw const ApiException(
          statusCode: 0,
          message:
              'Réponse inattendue du serveur Karavan lors de la connexion.');
    }

    ApiClient.instance.definirJeton(response['jeton'] as String);
    final profil = UtilisateurProfil.fromJson(
        response['profil'] as Map<String, dynamic>? ?? {});
    profilNotifier.value = profil;

    final refreshToken = response['refreshToken'] as String?;
    await SessionStorageService.instance.sauvegarderSession(
      refreshToken: refreshToken ?? '',
      profil: profil,
    );
    return profil;
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
    final secret = (motDePasse != null && motDePasse.isNotEmpty)
        ? motDePasse
        : (pin ?? '');
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

    final response =
        await ApiClient.instance.post(ApiConfig.inscription, body: body);
    return response is Map<String, dynamic> ? response : {};
  }

  /// Vérification de l'OTP reçu par SMS (RG-02)
  Future<Map<String, dynamic>> verifierOtp({
    required String telephone,
    required String code,
  }) async {
    final response = await ApiClient.instance.post(
      ApiConfig.verifierOtp,
      body: {
        'telephone': telephone,
        'code': code,
      },
    );
    return response is Map<String, dynamic> ? response : {};
  }

  /// Demande le renvoi d'un nouveau code OTP par SMS (RG-02)
  Future<Map<String, dynamic>> renvoyerOtp({
    required String telephone,
  }) async {
    final response = await ApiClient.instance.post(
      ApiConfig.renvoyerOtp,
      body: {
        'telephone': telephone,
      },
    );
    return response is Map<String, dynamic> ? response : {};
  }

  /// Demande de réinitialisation de mot de passe par SMS OTP (mot de passe oublié)
  Future<Map<String, dynamic>> demanderReinitialisationMotDePasse({
    required String telephone,
  }) async {
    final rep = await ApiClient.instance.postSansAuth(
      ApiConfig.demandeResetMdp,
      body: {'telephone': telephone},
      headers: _entetesPlateforme,
    );
    return rep is Map<String, dynamic> ? rep : <String, dynamic>{};
  }

  /// Validation du code OTP et définition du nouveau mot de passe
  Future<void> reinitialiserMotDePasse({
    required String telephone,
    required String code,
    required String nouveauMotDePasse,
  }) async {
    await ApiClient.instance.postSansAuth(
      ApiConfig.reinitialiserMdp,
      body: {
        'telephone': telephone,
        'code': code,
        'nouveauMotDePasse': nouveauMotDePasse,
      },
      headers: _entetesPlateforme,
    );
  }

  /// Authentification via jeton Auth0 (RG-07)
  /// Renvoie soit {'statut': 'CONNECTE', 'profil': ...} soit {'statut': 'PROFIL_INCOMPLET', 'jetonInscription': ...}
  Future<Map<String, dynamic>> authentifierAuth0(String idToken, {String? deviceId}) async {
    final response = await ApiClient.instance.postSansAuth(
      ApiConfig.auth0Auth,
      body: {
        'idToken': idToken,
        'deviceId': deviceId ?? 'flutter-device-client',
      },
      headers: _entetesPlateforme,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 0,
        message: 'Réponse inattendue du serveur lors de la connexion Auth0.',
      );
    }

    final String? jeton = response['jeton'] as String?;
    final statut = response['statut']?.toString();
    final bool estConnecte = (jeton != null && jeton.isNotEmpty) ||
        (statut == 'CONNECTE' && jeton != null && jeton.isNotEmpty);

    if (jeton != null && estConnecte) {
      ApiClient.instance.definirJeton(jeton);
      final profil = UtilisateurProfil.fromJson(
          response['profil'] as Map<String, dynamic>? ?? {});
      profilNotifier.value = profil;

      final refreshToken = response['refreshToken'] as String?;
      await SessionStorageService.instance.sauvegarderSession(
        refreshToken: refreshToken ?? '',
        profil: profil,
      );
      return {'statut': 'CONNECTE', 'profil': profil, 'jeton': jeton};
    }

    return response;
  }

  /// Étape 1 : Demande de code OTP pour finaliser l'inscription Auth0
  Future<Map<String, dynamic>> demanderOtpAuth0Completer({
    required String jetonInscription,
    required String telephone,
  }) async {
    final response = await ApiClient.instance.postSansAuth(
      ApiConfig.auth0DemanderOtp,
      body: {
        'jetonInscription': jetonInscription,
        'telephone': telephone,
      },
      headers: _entetesPlateforme,
    );
    return response is Map<String, dynamic> ? response : {};
  }

  /// Étape 2 : Vérification OTP et finalisation de l'inscription / fusion Auth0
  Future<UtilisateurProfil> completerAuth0EtConnecter({
    required String jetonInscription,
    required String telephone,
    required String codeOtp,
    String? typeActeur,
    String? nomBoutique,
    String? quartierBamako,
    String? deviceId,
  }) async {
    final response = await ApiClient.instance.postSansAuth(
      ApiConfig.auth0Completer,
      body: {
        'jetonInscription': jetonInscription,
        'telephone': telephone,
        'codeOtp': codeOtp,
        if (typeActeur != null) 'typeActeur': typeActeur.toUpperCase(),
        if (nomBoutique != null) 'nomBoutique': nomBoutique,
        if (quartierBamako != null) 'quartierBamako': quartierBamako,
        'deviceId': deviceId ?? 'flutter-device-client',
      },
      headers: _entetesPlateforme,
    );

    if (response is! Map<String, dynamic> || response['jeton'] is! String) {
      throw const ApiException(
        statusCode: 0,
        message: 'Réponse inattendue lors de la complétion du compte Auth0.',
      );
    }

    ApiClient.instance.definirJeton(response['jeton'] as String);
    final profil = UtilisateurProfil.fromJson(
        response['profil'] as Map<String, dynamic>? ?? {});
    profilNotifier.value = profil;

    final refreshToken = response['refreshToken'] as String?;
    await SessionStorageService.instance.sauvegarderSession(
      refreshToken: refreshToken ?? '',
      profil: profil,
    );

    return profil;
  }

  /// Rétrocompatibilité : redirection Google vers Auth0
  Future<Map<String, dynamic>> authentifierGoogle(String idToken, {String? deviceId}) =>
      authentifierAuth0(idToken, deviceId: deviceId);

  Future<Map<String, dynamic>> demanderOtpGoogleCompleter({
    required String jetonInscription,
    required String telephone,
  }) =>
      demanderOtpAuth0Completer(
        jetonInscription: jetonInscription,
        telephone: telephone,
      );

  Future<UtilisateurProfil> completerGoogleEtConnecter({
    required String jetonInscription,
    required String telephone,
    required String codeOtp,
    String? typeActeur,
    String? nomBoutique,
    String? quartierBamako,
    String? deviceId,
  }) =>
      completerAuth0EtConnecter(
        jetonInscription: jetonInscription,
        telephone: telephone,
        codeOtp: codeOtp,
        typeActeur: typeActeur,
        nomBoutique: nomBoutique,
        quartierBamako: quartierBamako,
        deviceId: deviceId,
      );

  /// Upload d'une photo de profil (JPEG, PNG, WEBP) vers le serveur (stockage sécurisé)
  Future<String> uploaderPhotoProfil(Uint8List octets,
      {String nom = 'avatar.jpg'}) async {
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
  }

  /// Supprime la photo de profil personnalisée
  Future<void> supprimerPhotoProfil() async {
    await ApiClient.instance.patch(
      ApiConfig.moi,
      body: {'photoUrl': ''},
    );
    if (profilActuel != null) {
      final maj = profilActuel!.sansPhoto();
      profilNotifier.value = maj;
      await SessionStorageService.instance.sauvegarderProfil(maj);
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
                telephone: nouveau.telephone.isNotEmpty
                    ? nouveau.telephone
                    : profilActuel!.telephone,
                photoUrl: nouveau.photoUrl,
                statut: nouveau.statut,
                nomStructure:
                    nouveau.nomStructure ?? profilActuel!.nomStructure,
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
      if (kIsWeb || (rt != null && rt.isNotEmpty)) {
        await ApiClient.instance.postSansAuth(
          ApiConfig.logout,
          body: kIsWeb ? null : {'refreshToken': rt},
          headers: _entetesPlateforme,
        );
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
