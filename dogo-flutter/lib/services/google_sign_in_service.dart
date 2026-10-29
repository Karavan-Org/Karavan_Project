import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/role_acteur.dart';
import '../screens/google_completer_profil_screen.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import 'auth_service.dart';

/// Service gérant Google Sign-In v7+ pour Flutter (Android & Web)
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  Future<void>? _initialisationFuture;
  bool _enCours = false;
  RoleActeur _roleEnCours = RoleActeur.commercant;
  GlobalKey<NavigatorState>? _navigatorKey;

  void definirNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  void definirRoleEnCours(RoleActeur role) {
    _roleEnCours = role;
  }

  /// Initialisation unique de Google Sign-In selon la doc officielle v7+
  Future<void> initialiser() {
    _initialisationFuture ??= _executerInitialisation();
    return _initialisationFuture!;
  }

  Future<void> _executerInitialisation() async {
    try {
      // Configuration officielle selon plateforme :
      // - Web : requiert clientId = Web Client ID (serverClientId doit être impérativement null)
      // - Android / iOS : requiert serverClientId = Web Client ID pour l'obtention du idToken backend
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? ApiConfig.googleClientId : null,
        serverClientId: kIsWeb ? null : ApiConfig.googleClientId,
      );

      // Écoute du flux réactif d'authentification (GIS Web & Credential Manager)
      GoogleSignIn.instance.authenticationEvents.listen(
        (GoogleSignInAuthenticationEvent event) {
          switch (event) {
            case GoogleSignInAuthenticationEventSignIn(:final user):
              _traiterAuthentificationStream(user);
              break;
            case GoogleSignInAuthenticationEventSignOut():
              debugPrint('Google Sign-In: Session fermée');
              break;
          }
        },
        onError: (err) {
          // Les annulations par l'utilisateur ou fermetures de popup ne sont pas des erreurs critiques
          if (err is GoogleSignInException &&
              (err.code == GoogleSignInExceptionCode.canceled ||
               err.code == GoogleSignInExceptionCode.interrupted)) {
            return;
          }
          debugPrint('Google Sign-In Stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation GoogleSignIn: $e');
    }
  }

  /// Déclenche la connexion interactive Google (bouton utilisateur sur mobile)
  Future<void> declencherConnexion(
    BuildContext context, {
    RoleActeur role = RoleActeur.commercant,
  }) async {
    if (_enCours) return;
    _roleEnCours = role;

    await initialiser();

    // Sur Android / iOS / Desktop (plateformes supportant l'authentification programmatique)
    if (GoogleSignIn.instance.supportsAuthenticate()) {
      _enCours = true;
      try {
        final GoogleSignInAccount account =
            await GoogleSignIn.instance.authenticate();

        final String? idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const ApiException(
            statusCode: 0,
            message:
                "Impossible d'obtenir le jeton d'authentification Google (idToken manquant).",
          );
        }

        if (context.mounted) {
          await _finaliserAvecBackend(
            context: context,
            idToken: idToken,
            account: account,
            role: role,
          );
        }
      } on GoogleSignInException catch (e) {
        if (e.code != GoogleSignInExceptionCode.canceled &&
            e.code != GoogleSignInExceptionCode.interrupted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Connexion Google échouée (${e.code.name})"),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e is ApiException
                  ? e.messageComplet
                  : "Erreur lors de la connexion Google."),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } finally {
        _enCours = false;
      }
    }
    // Sur le Web, le clic est géré de manière native et sécurisée par le bouton GIS officiel rendu
  }

  /// Traite l'authentification reçue via le flux de streaming (Web renderButton)
  Future<void> _traiterAuthentificationStream(GoogleSignInAccount user) async {
    final navContext = _navigatorKey?.currentContext;
    final String? idToken = user.authentication.idToken;
    if (idToken == null || idToken.isEmpty) return;

    if (navContext != null && navContext.mounted) {
      await _finaliserAvecBackend(
        context: navContext,
        idToken: idToken,
        account: user,
        role: _roleEnCours,
      );
    }
  }

  /// Appelle le backend Karavan pour valider le jeton Google et orienter l'utilisateur
  Future<void> _finaliserAvecBackend({
    required BuildContext context,
    required String idToken,
    required GoogleSignInAccount account,
    required RoleActeur role,
  }) async {
    try {
      final res = await AuthService.instance.authentifierGoogle(idToken);
      final statut = res['statut']?.toString();

      if (!context.mounted) return;

      if (statut == 'CONNECTE') {
        final profil = res['profil'] as UtilisateurProfil?;
        final roleFinal = profil?.roleActeur ?? role;
        final route = switch (roleFinal) {
          RoleActeur.grossiste => '/grossiste',
          RoleActeur.courtier => '/courtier',
          RoleActeur.commercant => '/commercant',
        };
        Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
      } else if (statut == 'PROFIL_INCOMPLET') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GoogleCompleterProfilScreen(
              jetonInscription: res['jetonInscription']?.toString() ?? '',
              sub: res['sub']?.toString() ?? account.id,
              email: res['email']?.toString() ?? account.email,
              emailVerified: res['emailVerified'] == true,
              nom: res['nom']?.toString() ?? account.displayName,
              photoUrl: res['photoUrl']?.toString() ?? account.photoUrl,
              roleParDefaut: role,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.messageComplet),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Erreur de connexion au serveur Karavan."),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}
