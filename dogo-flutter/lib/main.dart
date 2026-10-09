import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'commercant/ouvrir_groupe_screen.dart';
import 'services/lien_groupe.dart';
import 'theme/app_theme.dart';
import 'screens/splash_launch_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration de la barre de statut système
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const DogoApp());
}

class DogoApp extends StatelessWidget {
  const DogoApp({super.key});

  /// Lien d'invitation ouvert depuis l'extérieur : https://dogo.ml/groupe/12 arrive en « /groupe/12 »,
  /// dogo://groupe/12 en « /12 ».
  static int? _groupeDuLien(String? route) {
    if (route == null) return null;
    final chemin = Uri.tryParse(route)?.path ?? route;
    final m = RegExp(r'^/(?:groupe/)?(\d+)/?$').firstMatch(chemin);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Démarrage par un lien : le groupe s'ouvrira une fois le commerçant connecté
      onGenerateInitialRoutes: (route) {
        LienGroupe.enAttente = _groupeDuLien(route) ?? LienGroupe.enAttente;
        return [MaterialPageRoute(builder: (_) => const SplashLaunchScreen())];
      },
      // Lien reçu pendant que l'app tourne
      onGenerateRoute: (settings) {
        final id = _groupeDuLien(settings.name);
        if (id != null) {
          return MaterialPageRoute(builder: (_) => OuvrirGroupeScreen(groupeId: id), settings: settings);
        }
        if (settings.name == Navigator.defaultRouteName) {
          return MaterialPageRoute(builder: (_) => const SplashLaunchScreen(), settings: settings);
        }
        return null;
      },
    );
  }
}
