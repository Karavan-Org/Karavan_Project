import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../commercant/commercant_connexion_screen.dart';
import '../commercant/commercant_inscription_screen.dart';
import '../commercant/commercant_main_nav.dart';
import '../courtier/courtier_connexion_screen.dart';
import '../courtier/courtier_inscription_screen.dart';
import '../grossiste/grossiste_acces.dart';
import '../grossiste/grossiste_connexion_screen.dart';
import '../grossiste/grossiste_inscription_screen.dart';
import '../models/role_acteur.dart';
import '../screens/google_completer_profil_screen.dart';
import '../theme/app_theme.dart';
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
  bool _estInscriptionEnCours = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  void definirNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  void definirRoleEnCours(RoleActeur role) {
    _roleEnCours = role;
  }

  void definirContexteEnCours({
    required RoleActeur role,
    required bool estInscription,
  }) {
    _roleEnCours = role;
    _estInscriptionEnCours = estInscription;
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
    bool estInscription = false,
  }) async {
    if (_enCours) return;
    _roleEnCours = role;
    _estInscriptionEnCours = estInscription;

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
            estInscription: estInscription,
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
        estInscription: _estInscriptionEnCours,
      );
    }
  }

  /// Appelle le backend Karavan pour valider le jeton Google et orienter l'utilisateur :
  /// - En mode CONNEXION : connecte uniquement un compte existant ; s'il n'existe pas, suggère l'inscription.
  /// - En mode INSCRIPTION : lance la finalisation d'inscription Google ; s'il existe déjà, suggère la connexion.
  Future<void> _finaliserAvecBackend({
    required BuildContext context,
    required String idToken,
    required GoogleSignInAccount account,
    required RoleActeur role,
    required bool estInscription,
  }) async {
    try {
      final res = await AuthService.instance.authentifierGoogle(
        idToken,
        typeActeur: role.codeBackend,
        mode: estInscription ? 'INSCRIPTION' : 'CONNEXION',
      );
      final statut = res['statut']?.toString();

      if (!context.mounted) return;

      if (statut == 'CONNECTE') {
        final profil = res['profil'] as UtilisateurProfil?;
        final roleFinal = profil?.roleActeur ?? role;

        // Interdiction stricte de mélanger les espaces Commerçant, Grossiste et Courtier
        if (roleFinal != role) {
          await AuthService.instance.deconnecter();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Ce compte Google est déjà rattaché à un compte ${roleFinal.libelle} et ne peut pas être utilisé dans l'espace ${role.libelle}.",
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        if (roleFinal == RoleActeur.commercant || profil == null) {
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const CommercantMainNav()),
            (r) => false,
          );
        } else {
          // Grossiste et Courtier : soumis à validation selon leurs critères respectifs
          final destination = await ecranSelonStatut(profil, roleFinal);
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => destination),
            (r) => false,
          );
        }
      } else if (statut == 'PROFIL_INCOMPLET') {
        if (!estInscription) {
          await _proposerRedirectionInscription(
            context,
            role: role,
            email: res['email']?.toString() ?? account.email,
          );
          return;
        }

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
      if (!context.mounted) return;
      if (e.code == 'COMPTE_INEXISTANT') {
        await _proposerRedirectionInscription(
          context,
          role: role,
          email: account.email,
        );
        return;
      }
      if (e.code == 'CONFLIT' && estInscription) {
        await _proposerRedirectionConnexion(
          context,
          role: role,
          email: account.email,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.messageComplet),
          backgroundColor: Colors.red.shade700,
        ),
      );
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

  Future<void> _proposerRedirectionInscription(
    BuildContext context, {
    required RoleActeur role,
    required String email,
  }) async {
    final bool? allerInscription = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.couleurCarte(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.person_search_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Aucun compte ${role.libelle}",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexte(dialogContext),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          email.isNotEmpty
              ? "Aucun compte ${role.libelle.toLowerCase()} n'est encore associé à l'adresse $email.\n\nSouhaitez-vous ouvrir l'écran d'inscription ? Vous pourrez y choisir « S'inscrire avec Google »."
              : "Aucun compte ${role.libelle.toLowerCase()} n'est associé à ce compte Google.\n\nSouhaitez-vous ouvrir l'écran d'inscription ? Vous pourrez y choisir « S'inscrire avec Google ».",
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: AppTheme.couleurTexteAttenue(dialogContext),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Fermer"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "S'inscrire",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (allerInscription == true && context.mounted) {
      final Widget destination = switch (role) {
        RoleActeur.commercant =>
          const CommercantInscriptionScreen(role: RoleActeur.commercant),
        RoleActeur.grossiste => const GrossisteInscriptionScreen(),
        RoleActeur.courtier => const CourtierInscriptionScreen(),
      };
      definirContexteEnCours(role: role, estInscription: true);
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => destination))
          .then((_) {
            definirContexteEnCours(role: role, estInscription: false);
          });
    }
  }

  Future<void> _proposerRedirectionConnexion(
    BuildContext context, {
    required RoleActeur role,
    required String email,
  }) async {
    final bool? allerConnexion = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.couleurCarte(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.login_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Compte déjà existant",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexte(dialogContext),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          email.isNotEmpty
              ? "Un compte ${role.libelle.toLowerCase()} existe déjà avec l'adresse $email.\n\nVeuillez passer par l'écran de connexion et choisir « Continuer avec Google »."
              : "Un compte ${role.libelle.toLowerCase()} existe déjà pour ce compte Google.\n\nVeuillez passer par l'écran de connexion.",
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: AppTheme.couleurTexteAttenue(dialogContext),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Fermer"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Se connecter",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (allerConnexion == true && context.mounted) {
      definirContexteEnCours(role: role, estInscription: false);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        final Widget destination = switch (role) {
          RoleActeur.commercant =>
            const CommercantConnexionScreen(role: RoleActeur.commercant),
          RoleActeur.grossiste => const GrossisteConnexionScreen(),
          RoleActeur.courtier => const CourtierConnexionScreen(),
        };
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => destination),
        );
      }
    }
  }
}
