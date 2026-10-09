import 'package:flutter/foundation.dart';

/// Configuration centralisée des endpoints et URLs de l'API Backend DoGo
class ApiConfig {
  ApiConfig._();

  /// Paramètres passés au démarrage (ex: flutter run --dart-define=ip=10.13.11.11)
  static const String _ipParam = String.fromEnvironment('ip', defaultValue: '');
  static const String _portParam = String.fromEnvironment('port', defaultValue: '8080');

  /// URL de base configurable.
  /// Priorité :
  /// 1. Paramètre --dart-define=ip=... (ex: --dart-define=ip=10.13.11.11)
  /// 2. Détection automatique selon la plateforme (Web: localhost, Android: 10.0.2.2, iOS: localhost)
  static String get baseUrl {
    if (_ipParam.isNotEmpty) {
      final ip = _ipParam.trim();
      final scheme = (ip.startsWith('http://') || ip.startsWith('https://')) ? '' : 'http://';
      final sansScheme = ip.replaceFirst(RegExp(r'^https?://'), '');
      final portSuffix = sansScheme.contains(':') ? '' : ':$_portParam';
      final completeUrl = '$scheme$ip$portSuffix';
      return completeUrl.endsWith('/') ? completeUrl.substring(0, completeUrl.length - 1) : completeUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // Sur émulateur Android, localhost de la machine hôte est 10.0.2.2
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    // iOS, macOS, Windows, Linux
    return 'http://localhost:8080';
  }

  /// Timeout par défaut pour les connexions réseau
  static const Duration timeout = Duration(seconds: 15);

  // --- Endpoints Authentification ---
  static const String inscription = '/api/auth/inscription';
  static const String connexion = '/api/auth/connexion';
  static const String verifierOtp = '/api/auth/verifier-otp';
  static const String renvoyerOtp = '/api/auth/renvoyer-otp';

  // --- Endpoints Dossier KYC (Grossiste / Courtier) ---
  static const String kyc = '/api/kyc';
  static const String monDossierKyc = '/api/kyc/moi';

  // --- Endpoints Groupes d'Achat ---
  static const String groupes = '/api/groupes';
  static const String mesGroupes = '/api/groupes/mes-groupes';
  static const String groupesAValider = '/api/groupes/a-valider';

  static String groupeDetail(dynamic id) => '/api/groupes/$id';
  static String rejoindreGroupe(dynamic groupeId) => '/api/groupes/$groupeId/participations';

  // --- Endpoints Paiements & Séquestre ---
  static String initierPaiement(dynamic participationId) => '/api/participations/$participationId/paiement';
  static String historiquePaiements(dynamic participationId) => '/api/participations/$participationId/paiements';

  // --- Endpoints Logistique & Commandes ---
  static const String mesCommandes = '/api/moi/commandes';
  static String commandeDetail(dynamic id) => '/api/commandes/$id';
  static String codeRetrait(dynamic commandeId) => '/api/commandes/$commandeId/code-retrait';
  static const String validerRetrait = '/api/retraits/valider';
  static const String pointsRetrait = '/api/points-retrait';

  // --- Endpoints Catalogue Grossiste & Upload Photos ---
  static const String catalogueProduits = '/api/catalogue/produits';
  static const String catalogueCategories = '/api/catalogue/categories';
  static const String catalogueUploadPhoto = '/api/catalogue/upload-photo';

  /// Résout une URL d'image (ex: /api/public/images/produits/xyz.jpg -> http://localhost:8080/api/public/images/produits/xyz.jpg)
  static String resolutionImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final chemin = url.startsWith('/') ? url : '/$url';
    return '$base$chemin';
  }
}
