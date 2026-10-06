import 'package:flutter/foundation.dart';

/// Configuration centralisée des endpoints et URLs de l'API Backend DoGo
class ApiConfig {
  ApiConfig._();

  /// URL de base configurable. Détection automatique selon la plateforme.
  static String get baseUrl {
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
}
