import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/role_acteur.dart';
import '../models/utilisateur_profil.dart';
import 'tab_storage_helper.dart';

/// Service de stockage sécurisé du jeton de rafraîchissement, du profil local et de l'espace actif (RG-07, RG-08)
/// avec isolation multi-onglets (sessionStorage) pour permettre d'avoir simultanément des onglets
/// Commerçant, Grossiste et Courtier sans interférence ni perte de rôle lors d'un rafraîchissement.
class SessionStorageService {
  SessionStorageService._();
  static final SessionStorageService instance = SessionStorageService._();

  static const String _cleRefreshToken = 'dogo_refresh_token';
  static const String _cleProfil = 'dogo_user_profil';
  static const String _cleDernierEspace = 'dogo_dernier_espace';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _dernierEspaceEnMemoire;
  String? get dernierEspaceEnMemoire => _dernierEspaceEnMemoire;

  static String? _espaceDuRole(RoleActeur? role) {
    if (role == null) return null;
    switch (role) {
      case RoleActeur.commercant:
        return 'commercant';
      case RoleActeur.grossiste:
        return 'grossiste';
      case RoleActeur.courtier:
        return 'courtier';
    }
  }

  /// Enregistre le refresh token long et les métadonnées de l'utilisateur
  /// dans l'onglet courant (sessionStorage) et dans le stockage sécurisé par rôle
  Future<void> sauvegarderSession({
    required String refreshToken,
    required UtilisateurProfil profil,
  }) async {
    final espace = _espaceDuRole(profil.roleActeur);
    final profilJson = jsonEncode(profil.toJson());

    // 1. Stockage isolé propre à cet onglet (sessionStorage web)
    if (kIsWeb) {
      await _effacerJetonsWeb();
    } else {
      setSessionStorageItem('dogo_tab_refresh_token', refreshToken);
    }
    setSessionStorageItem('dogo_tab_profil', profilJson);
    if (espace != null) {
      setSessionStorageItem('dogo_tab_espace', espace);
      _dernierEspaceEnMemoire = espace;
      // 2. Stockage persistant cloisonné par rôle pour préserver les sessions distinctes
      try {
        if (!kIsWeb) {
          await _storage.write(
              key: '${_cleRefreshToken}_$espace', value: refreshToken);
        }
        await _storage.write(key: '${_cleProfil}_$espace', value: profilJson);
      } catch (_) {}
    }

    // 3. Stockage générique par défaut
    try {
      if (!kIsWeb) {
        await _storage.write(key: _cleRefreshToken, value: refreshToken);
      }
      await _storage.write(key: _cleProfil, value: profilJson);
    } catch (_) {}
  }

  /// Met à jour les métadonnées du profil utilisateur en cache local
  Future<void> sauvegarderProfil(UtilisateurProfil profil) async {
    final profilJson = jsonEncode(profil.toJson());
    final espace = _espaceDuRole(profil.roleActeur);

    setSessionStorageItem('dogo_tab_profil', profilJson);
    if (espace != null) {
      try {
        await _storage.write(key: '${_cleProfil}_$espace', value: profilJson);
      } catch (_) {}
    }

    try {
      await _storage.write(key: _cleProfil, value: profilJson);
    } catch (_) {}
  }

  /// Lit le refresh token stocké de manière sécurisée (priorité à l'onglet courant puis à l'espace URL)
  Future<String?> lireRefreshToken() async {
    if (kIsWeb) {
      await _effacerJetonsWeb();
      return null;
    }
    // 1. Priorité absolue : le jeton propre à cet onglet (survit au F5 de cet onglet uniquement)
    final tabToken = getSessionStorageItem('dogo_tab_refresh_token');
    if (tabToken != null && tabToken.isNotEmpty) {
      return tabToken;
    }

    // 2. Priorité par espace : si l'onglet cible un espace particulier (/commercant, /grossiste, /courtier)
    final espace = detecterEspaceUrlOnglet() ??
        getSessionStorageItem('dogo_tab_espace') ??
        _dernierEspaceEnMemoire;
    if (espace != null && espace.isNotEmpty) {
      try {
        final espaceToken = await _storage.read(
            key: '${_cleRefreshToken}_${espace.toLowerCase()}');
        if (espaceToken != null && espaceToken.isNotEmpty) {
          return espaceToken;
        }
      } catch (_) {}
    }

    // 3. Fallback stockage global
    try {
      return await _storage.read(key: _cleRefreshToken);
    } catch (_) {
      return null;
    }
  }

  /// Restaure le profil utilisateur mis en cache
  Future<UtilisateurProfil?> lireProfil() async {
    // 1. Priorité absolue : profil de cet onglet
    final tabProfilStr = getSessionStorageItem('dogo_tab_profil');
    if (tabProfilStr != null && tabProfilStr.isNotEmpty) {
      try {
        final map = jsonDecode(tabProfilStr) as Map<String, dynamic>;
        return UtilisateurProfil.fromJson(map);
      } catch (_) {}
    }

    // 2. Priorité par espace ciblé par l'onglet
    final espace = detecterEspaceUrlOnglet() ??
        getSessionStorageItem('dogo_tab_espace') ??
        _dernierEspaceEnMemoire;
    if (espace != null && espace.isNotEmpty) {
      try {
        final espaceProfilStr =
            await _storage.read(key: '${_cleProfil}_${espace.toLowerCase()}');
        if (espaceProfilStr != null && espaceProfilStr.isNotEmpty) {
          final map = jsonDecode(espaceProfilStr) as Map<String, dynamic>;
          return UtilisateurProfil.fromJson(map);
        }
      } catch (_) {}
    }

    // 3. Fallback stockage global
    try {
      final jsonStr = await _storage.read(key: _cleProfil);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UtilisateurProfil.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Enregistre l'espace actif (commercant, courtier, grossiste) pour préserver l'écran lors d'un rafraîchissement
  Future<void> sauvegarderDernierEspace(String espace) async {
    final e = espace.toLowerCase();
    _dernierEspaceEnMemoire = e;
    setSessionStorageItem('dogo_tab_espace', e);
    try {
      await _storage.write(key: _cleDernierEspace, value: e);
    } catch (_) {}
  }

  /// Récupère le dernier espace actif (URL de l'onglet > sessionStorage de l'onglet > mémoire > stockage)
  Future<String?> lireDernierEspace() async {
    // 1. Détection prioritaire par l'URL propre à cet onglet (#/commercant, #/grossiste, #/courtier)
    final urlEspace = detecterEspaceUrlOnglet();
    if (urlEspace != null && urlEspace.isNotEmpty) {
      _dernierEspaceEnMemoire = urlEspace.toLowerCase();
      return _dernierEspaceEnMemoire;
    }

    // 2. Détection par le stockage isolé de l'onglet (sessionStorage)
    final tabEspace = getSessionStorageItem('dogo_tab_espace');
    if (tabEspace != null && tabEspace.isNotEmpty) {
      _dernierEspaceEnMemoire = tabEspace.toLowerCase();
      return _dernierEspaceEnMemoire;
    }

    // 3. Mémoire volatile
    if (_dernierEspaceEnMemoire != null &&
        _dernierEspaceEnMemoire!.isNotEmpty) {
      return _dernierEspaceEnMemoire;
    }

    // 4. Stockage persistant
    try {
      final val = await _storage.read(key: _cleDernierEspace);
      if (val != null && val.isNotEmpty) {
        _dernierEspaceEnMemoire = val.toLowerCase();
        return _dernierEspaceEnMemoire;
      }
    } catch (_) {}
    return null;
  }

  /// Efface toutes les clés de session lors de la déconnexion
  Future<void> effacerSession() async {
    final espace = _dernierEspaceEnMemoire;
    _dernierEspaceEnMemoire = null;

    removeSessionStorageItem('dogo_tab_refresh_token');
    removeSessionStorageItem('dogo_tab_profil');
    removeSessionStorageItem('dogo_tab_espace');

    try {
      if (kIsWeb) {
        await _effacerJetonsWeb();
      }
      if (espace != null) {
        await _storage.delete(key: '${_cleRefreshToken}_$espace');
        await _storage.delete(key: '${_cleProfil}_$espace');
      }
      await _storage.delete(key: _cleRefreshToken);
      await _storage.delete(key: _cleProfil);
      await _storage.delete(key: _cleDernierEspace);
    } catch (_) {}
  }

  Future<void> _effacerJetonsWeb() async {
    removeSessionStorageItem('dogo_tab_refresh_token');
    for (final key in [
      _cleRefreshToken,
      '${_cleRefreshToken}_commercant',
      '${_cleRefreshToken}_grossiste',
      '${_cleRefreshToken}_courtier',
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
    }
  }

  /// Vérifie si le didacticiel d'accueil a déjà été visualisé pour un rôle et un identifiant
  Future<bool> aDejaVuGuide(String role, String identifiant) async {
    try {
      final key = 'dogo_guide_${role.toLowerCase()}_vu_$identifiant';
      final val = await _storage.read(key: key);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Marque le didacticiel d'accueil comme lu pour un rôle et un utilisateur
  Future<void> marquerGuideVu(String role, String identifiant) async {
    try {
      final key = 'dogo_guide_${role.toLowerCase()}_vu_$identifiant';
      await _storage.write(key: key, value: 'true');
    } catch (_) {}
  }

  /// Réinitialise l'état du guide pour permettre de le revoir
  Future<void> reinitialiserGuide(String role, String identifiant) async {
    try {
      final key = 'dogo_guide_${role.toLowerCase()}_vu_$identifiant';
      await _storage.delete(key: key);
    } catch (_) {}
  }

  /// Rétro-compatibilité pour le rôle Grossiste
  Future<bool> aDejaVuGuideGrossiste(String identifiant) =>
      aDejaVuGuide('grossiste', identifiant);
  Future<void> marquerGuideGrossisteVu(String identifiant) =>
      marquerGuideVu('grossiste', identifiant);
  Future<void> reinitialiserGuideGrossiste(String identifiant) =>
      reinitialiserGuide('grossiste', identifiant);
}
