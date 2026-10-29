import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'tab_storage_helper.dart';

/// Service réactif de gestion du Thème (Clair / Sombre / Système)
/// avec persistance dans le stockage sécurisé et le sessionStorage de l'onglet courant.
class ThemeService {
  ThemeService._internal();
  static final ThemeService instance = ThemeService._internal();

  static const String _cleTheme = 'karavan_theme_mode';
  static const String _cleThemeLegacy = 'dogo_theme_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Notifieur réactif écouté par la racine MaterialApp
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  ThemeMode get modeActuel => themeModeNotifier.value;

  /// Vérifie si l'application s'affiche actuellement en sombre (en prenant en compte le système)
  bool estSombre(BuildContext context) {
    if (themeModeNotifier.value == ThemeMode.dark) return true;
    if (themeModeNotifier.value == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  /// Initialise la préférence stockée au démarrage
  Future<void> initialiser() async {
    try {
      // 1. Lire d'abord depuis le stockage web de l'onglet
      String? valeur = getSessionStorageItem(_cleTheme) ?? getSessionStorageItem(_cleThemeLegacy);
      // 2. Sinon lire depuis le stockage sécurisé persistant
      if (valeur == null || valeur.isEmpty) {
        valeur = (await _storage
                .read(key: _cleTheme)
                .timeout(const Duration(milliseconds: 300), onTimeout: () => null)) ??
            (await _storage
                .read(key: _cleThemeLegacy)
                .timeout(const Duration(milliseconds: 300), onTimeout: () => null));
      }
      if (valeur == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else if (valeur == 'system') {
        themeModeNotifier.value = ThemeMode.system;
      } else {
        themeModeNotifier.value = ThemeMode.light;
      }
    } catch (_) {
      themeModeNotifier.value = ThemeMode.light;
    }
  }

  /// Modifie et persiste le mode choisi
  Future<void> changerMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final chaine = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.system
            ? 'system'
            : 'light';
    try {
      setSessionStorageItem(_cleTheme, chaine);
      await _storage
          .write(key: _cleTheme, value: chaine)
          .timeout(const Duration(milliseconds: 300), onTimeout: () {});
    } catch (_) {}
  }

  /// Bascule instantanément entre Clair et Sombre
  Future<void> basculerMode(BuildContext context) async {
    final sombre = estSombre(context);
    await changerMode(sombre ? ThemeMode.light : ThemeMode.dark);
  }
}

