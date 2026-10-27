import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'commercant/commercant_main_nav.dart';
import 'commercant/ouvrir_groupe_screen.dart';
import 'courtier/courtier_main_nav.dart';
import 'grossiste/grossiste_documents_kyc_screen.dart';
import 'grossiste/grossiste_main_nav.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_launch_screen.dart';
import 'models/role_acteur.dart';
import 'services/api/api_config.dart';
import 'services/lien_groupe.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chargement de la préférence de thème (clair/sombre)
  await ThemeService.instance.initialiser();

  // Configuration de la barre de statut système
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Rappel en console du backend ciblé (--dart-define=ip=... / port=...)
  debugPrint('Karavan API : ${ApiConfig.baseUrl}');

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Karavan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          // Démarrage par un lien ou rafraîchissement d'un espace spécifique
          onGenerateInitialRoutes: (route) {
            LienGroupe.enAttente = _groupeDuLien(route) ?? LienGroupe.enAttente;
            return [MaterialPageRoute(builder: (_) => SplashLaunchScreen(routeInitiale: route))];
          },
      // Table des routes nommées pour la navigation directe et web
      routes: {
        '/commercant': (_) => const CommercantMainNav(),
        '/courtier': (_) => const CourtierMainNav(),
        '/grossiste': (_) => const GrossisteMainNav(),
        '/onboarding': (_) => const OnboardingScreen(),
      },
      // Lien reçu pendant que l'app tourne ou navigation dynamique
      onGenerateRoute: (settings) {
        final id = _groupeDuLien(settings.name);
        if (id != null) {
          return MaterialPageRoute(builder: (_) => OuvrirGroupeScreen(groupeId: id), settings: settings);
        }
        if (settings.name == '/commercant') {
          return MaterialPageRoute(builder: (_) => const CommercantMainNav(), settings: settings);
        }
        if (settings.name == '/courtier') {
          return MaterialPageRoute(builder: (_) => const CourtierMainNav(), settings: settings);
        }
        if (settings.name == '/grossiste') {
          return MaterialPageRoute(builder: (_) => const GrossisteMainNav(), settings: settings);
        }
        if (settings.name == '/grossiste/kyc') {
          final motif = settings.arguments as String?;
          return MaterialPageRoute(builder: (_) => GrossisteDocumentsKycScreen(motifRejet: motif), settings: settings);
        }
        if (settings.name == '/courtier/kyc') {
          final motif = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => GrossisteDocumentsKycScreen(motifRejet: motif, role: RoleActeur.courtier),
            settings: settings,
          );
        }
        if (settings.name == '/onboarding') {
          return MaterialPageRoute(builder: (_) => const OnboardingScreen(), settings: settings);
        }
        if (settings.name == Navigator.defaultRouteName || settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const SplashLaunchScreen(), settings: settings);
        }
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => SplashLaunchScreen(routeInitiale: settings.name),
          settings: settings,
        );
      },
    );
  },
);
  }
}
