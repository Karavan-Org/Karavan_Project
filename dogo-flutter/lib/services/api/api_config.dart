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
  /// Surcharge de l'URL de base, réservée aux tests (serveur HTTP local).
  @visibleForTesting
  static String? baseUrlTest;

  static String get baseUrl {
    if (baseUrlTest != null) return baseUrlTest!;
    if (_ipParam.isNotEmpty) {
      final ip = _ipParam.trim();
      final scheme = (ip.startsWith('http://') || ip.startsWith('https://')) ? '' : 'http://';
      final sansScheme = ip.replaceFirst(RegExp(r'^https?://'), '');
      // Une URL https (https://api.dogo.ml) garde son port implicite 443, sauf --dart-define=port explicite.
      final portImplicite = ip.startsWith('https://') && !const bool.hasEnvironment('port');
      final portSuffix = (sansScheme.contains(':') || portImplicite) ? '' : ':$_portParam';
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
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String deconnexion = '/api/moi/deconnexion';
  static const String notifications = '/api/moi/notifications';
  static const String moi = '/api/moi';
  static const String photoProfil = '/api/moi/photo';
  static const String changerMotDePasse = '/api/moi/mot-de-passe';
  static const String verifierOtp = '/api/auth/verifier-otp';
  static const String renvoyerOtp = '/api/auth/renvoyer-otp';
  static const String demandeResetMdp = '/api/auth/mot-de-passe-oublie/demande';
  static const String reinitialiserMdp = '/api/auth/mot-de-passe-oublie/reinitialiser';

  // --- Endpoints Dossier KYC (Grossiste / Courtier) ---
  static const String kyc = '/api/kyc';
  static const String monDossierKyc = '/api/kyc/moi';

  // --- Endpoints Groupes d'Achat ---
  static const String groupes = '/api/groupes';
  static const String mesGroupes = '/api/groupes/mes-groupes';
  static const String groupesAValider = '/api/groupes/a-valider';
  static const String groupesDuGrossiste = '/api/groupes/du-grossiste';

  static String groupeDetail(dynamic id) => '/api/groupes/$id';
  static String rejoindreGroupe(dynamic groupeId) => '/api/groupes/$groupeId/participations';
  static String soumettreGroupe(dynamic id) => '/api/groupes/$id/soumission';
  static String annulerGroupe(dynamic id) => '/api/groupes/$id/annulation';
  static String disponibiliteGroupe(dynamic id) => '/api/groupes/$id/disponibilite';
  static String commandesDuGroupe(dynamic id) => '/api/groupes/$id/commandes';
  static String preparerGroupe(dynamic id) => '/api/groupes/$id/preparation';
  static String expedierGroupe(dynamic id) => '/api/groupes/$id/expedition';
  static String arriveePointRetrait(dynamic id) => '/api/groupes/$id/reception-point-retrait';

  // --- Endpoints Convois Logistique ---
  static const String convois = '/api/convois';
  static String convoiAction(dynamic id, String action) => '/api/convois/$id/$action';

  // --- Endpoints Paiements & Séquestre ---
  static String initierPaiement(dynamic participationId) => '/api/participations/$participationId/paiement';
  static String historiquePaiements(dynamic participationId) => '/api/participations/$participationId/paiements';
  static String simulerSuccesPaiement(dynamic paiementId) => '/api/dev/mobile-money/$paiementId/succes';
  static const String portefeuille = '/api/moi/portefeuille';
  static const String portefeuilleMouvements = '/api/moi/portefeuille/mouvements';
  static const String portefeuilleRecharge = '/api/moi/portefeuille/recharge';
  static const String portefeuilleRetraits = '/api/moi/portefeuille/retraits';

  // --- Endpoints Participations (Commerçant, RG-26 à RG-32) ---
  static const String mesParticipations = '/api/moi/participations';
  static const String mesRemboursements = '/api/moi/remboursements';
  static String participationDetail(dynamic id) => '/api/participations/$id';
  static String participationHistorique(dynamic id) => '/api/participations/$id/historique';
  static String annulerParticipation(dynamic id) => '/api/participations/$id/annulation';

  // --- Endpoints Logistique & Commandes ---
  static const String mesCommandes = '/api/moi/commandes';
  static String commandeDetail(dynamic id) => '/api/commandes/$id';
  static String codeRetrait(dynamic commandeId) => '/api/commandes/$commandeId/code-retrait';
  static const String validerRetrait = '/api/retraits/valider';
  static const String pointsRetrait = '/api/points-retrait';

  // --- Endpoints Catalogue Grossiste & Upload Photos ---
  static const String catalogueProduits = '/api/catalogue/produits';
  static const String produitsDisponibles = '/api/catalogue/produits-disponibles';
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
