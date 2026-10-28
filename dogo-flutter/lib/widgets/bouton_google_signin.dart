import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/role_acteur.dart';
import '../screens/google_completer_profil_screen.dart';
import '../services/api/api_config.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Bouton officiel « Continuer avec Google » respectant la charte graphique Google et l'identité visuelle Karavan.
class BoutonGoogleSignIn extends StatelessWidget {
  final RoleActeur role;
  final String libelle;
  final VoidCallback? onAvantClic;
  final ValueChanged<String>? onTelephoneConfirme;

  const BoutonGoogleSignIn({
    super.key,
    required this.role,
    this.libelle = "Continuer avec Google",
    this.onAvantClic,
    this.onTelephoneConfirme,
  });

  Future<void> _declencherConnexionGoogle(BuildContext context) async {
    if (onAvantClic != null) onAvantClic!();

    final scaffold = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    // En environnement de test / local sans ID client Google configuré,
    // ouvrir la boîte de dialogue de démonstration assistée
    if (ApiConfig.googleClientId.isEmpty) {
      GoogleAuthModal.ouvrir(context: context, role: role);
      return;
    }

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: ApiConfig.googleClientId,
        scopes: const ['email', 'profile'],
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        scaffold.showSnackBar(
          const SnackBar(
            content: Text("Connexion Google annulée."),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception("Impossible d'obtenir les identifiants de connexion Google.");
      }

      final res = await AuthService.instance.authentifierGoogle(idToken);
      final statut = res['statut']?.toString();
      final String? jeton = res['jeton'] as String?;
      final bool estConnecte = statut == 'CONNECTE' || (jeton != null && jeton.isNotEmpty);
      if (estConnecte) {
        final profil = AuthService.instance.profilActuel;
        final roleEffectif = profil?.roleActeur ?? role;
        if (profil != null && profil.roleActeur != role) {
          scaffold.showSnackBar(
            SnackBar(
              content: Text(
                "Ce compte Google est associé au profil ${profil.roleActeur.libelle}. Redirection vers votre espace ${profil.roleActeur.libelle}...",
              ),
              backgroundColor: AppTheme.primary,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        final route = switch (roleEffectif) {
          RoleActeur.grossiste => '/grossiste',
          RoleActeur.courtier => '/courtier',
          RoleActeur.commercant => '/commercant',
        };
        nav.pushReplacementNamed(route);
      } else if (statut == 'PROFIL_INCOMPLET') {
        nav.push(
          MaterialPageRoute(
            builder: (_) => GoogleCompleterProfilScreen(
              jetonInscription: res['jetonInscription']?.toString() ?? '',
              sub: res['sub']?.toString(),
              email: res['email']?.toString() ?? account.email,
              emailVerified: res['emailVerified'] == true,
              nom: res['nom']?.toString() ?? account.displayName,
              photoUrl: res['photoUrl']?.toString() ?? account.photoUrl,
              roleParDefaut: role,
            ),
          ),
        );
      } else {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? "Réponse inattendue lors de la connexion."),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } on ApiException catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(e.messageComplet),
          backgroundColor: AppTheme.danger,
        ),
      );
    } catch (_) {
      scaffold.showSnackBar(
        const SnackBar(
          content: Text("Impossible de finaliser l'authentification Google. Veuillez réessayer."),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = AppTheme.estSombre(context);
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);

    return InkWell(
      onTap: () => _declencherConnexionGoogle(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: couleurCarte,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: estSombre ? couleurBordure : const Color(0xFFDADCE0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: estSombre ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GoogleGIcon(taille: 22),
            const SizedBox(width: 12),
            Text(
              libelle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: couleurTexte,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo vectoriel officiel Google « G » 4 couleurs (Bleu, Rouge, Jaune, Vert)
class GoogleGIcon extends StatelessWidget {
  final double taille;

  const GoogleGIcon({super.key, this.taille = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: Image.asset(
        'assets/logo/Google__G__logo.svg.webp',
        width: taille,
        height: taille,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          painter: _GoogleGLogoPainter(),
        ),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centre = Offset(w / 2, h / 2);
    final rayonExt = w * 0.48;
    final epaisseur = w * 0.22;
    final rect = Rect.fromCircle(center: centre, radius: rayonExt);

    final paintBleu = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    final paintRouge = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    final paintJaune = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    final paintVert = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    // Arcs formant le cercle Google
    canvas.drawArc(rect, -0.6, 1.2, false, paintBleu);
    canvas.drawArc(rect, 0.6, 1.2, false, paintVert);
    canvas.drawArc(rect, 1.8, 1.2, false, paintJaune);
    canvas.drawArc(rect, 3.0, 1.2, false, paintRouge);

    // Barre transversale bleue du "G"
    final paintBarre = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final rectBarre = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.44, h * 0.40, w * 0.50, h * 0.20),
      const Radius.circular(2),
    );
    canvas.drawRRect(rectBarre, paintBarre);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Modal moderne d'authentification Google (avec support du mode démo/test)
class GoogleAuthModal extends StatefulWidget {
  final RoleActeur role;

  const GoogleAuthModal({super.key, required this.role});

  static Future<void> ouvrir({
    required BuildContext context,
    required RoleActeur role,
  }) {
    final largeEcran = MediaQuery.of(context).size.width >= 600;
    if (largeEcran) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GoogleAuthModal(role: role),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoogleAuthModal(role: role),
    );
  }

  @override
  State<GoogleAuthModal> createState() => _GoogleAuthModalState();
}

class _GoogleAuthModalState extends State<GoogleAuthModal> {
  final List<Map<String, String>> _comptesDisponibles = const [
    {
      'nom': 'Salif Modibo Keïta',
      'email': 'salifmodibok@gmail.com',
      'sub': 'google-uid-salif',
    },
    {
      'nom': 'Mamadou Touré (Grossiste)',
      'email': 'grossiste.toure@gmail.com',
      'sub': 'google-uid-grossiste',
    },
    {
      'nom': 'Ousmane Traoré (Courtier)',
      'email': 'courtier.traore@gmail.com',
      'sub': 'google-uid-courtier',
    },
  ];
  int _indexSelectionne = 0;
  bool _enCours = false;
  String? _messageErreur;

  Future<void> _lancerAuthentificationSimulee() async {
    setState(() {
      _enCours = true;
      _messageErreur = null;
    });

    final nav = Navigator.of(context);
    final compte = _comptesDisponibles[_indexSelectionne];
    final nomGoogle = compte['nom']!;
    final emailGoogle = compte['email']!;
    final subGoogle = compte['sub']!;

    try {
      // Émission d'un mock token Google valide pour le backend en profil local/demo
      final token = 'mock-google-token:$subGoogle:$emailGoogle:true:$nomGoogle:';
      final res = await AuthService.instance.authentifierGoogle(token);

      if (!mounted) return;

      final statut = res['statut']?.toString();
      final String? jeton = res['jeton'] as String?;
      final bool estConnecte = statut == 'CONNECTE' || (jeton != null && jeton.isNotEmpty);

      if (estConnecte) {
        nav.pop(); // Fermer la modale
        final profil = AuthService.instance.profilActuel;
        final roleEffectif = profil?.roleActeur ?? widget.role;

        if (profil != null && profil.roleActeur != widget.role) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Ce compte Google est enregistré en tant que ${profil.roleActeur.libelle}. Redirection vers votre espace ${profil.roleActeur.libelle}...",
              ),
              backgroundColor: AppTheme.primary,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        final route = switch (roleEffectif) {
          RoleActeur.grossiste => '/grossiste',
          RoleActeur.courtier => '/courtier',
          RoleActeur.commercant => '/commercant',
        };
        nav.pushReplacementNamed(route);
      } else if (statut == 'PROFIL_INCOMPLET') {
        nav.pop(); // Fermer la modale
        nav.push(
          MaterialPageRoute(
            builder: (_) => GoogleCompleterProfilScreen(
              jetonInscription: res['jetonInscription']?.toString() ?? '',
              sub: res['sub']?.toString(),
              email: res['email']?.toString() ?? emailGoogle,
              emailVerified: res['emailVerified'] == true,
              nom: res['nom']?.toString() ?? nomGoogle,
              photoUrl: res['photoUrl']?.toString(),
              roleParDefaut: widget.role,
            ),
          ),
        );
      } else {
        setState(() {
          _enCours = false;
          _messageErreur = res['message']?.toString() ?? "Réponse inattendue lors de la connexion.";
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _enCours = false;
        _messageErreur = e.messageComplet;
      });
    } catch (_) {
      setState(() {
        _enCours = false;
        _messageErreur = "Une erreur est survenue lors de la connexion. Veuillez réessayer.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = AppTheme.estSombre(context);
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);

    return Container(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      decoration: BoxDecoration(
        color: couleurCarte,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: couleurBordure, width: 1.2),
        boxShadow: AppTheme.ombreDouce,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: couleurBordure,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: estSombre ? Colors.black26 : const Color(0xFFF1F3F4),
                    shape: BoxShape.circle,
                    border: Border.all(color: couleurBordure),
                  ),
                  child: const Center(child: GoogleGIcon(taille: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Connexion Google",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: couleurTexte,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Espace ${widget.role.libelle} Karavan",
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.doreKaravan,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: couleurAttenue),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              "Choisissez un compte Google :",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: couleurAttenue,
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _comptesDisponibles.length; i++) ...[
              Builder(builder: (_) {
                final compte = _comptesDisponibles[i];
                final estSelectionne = i == _indexSelectionne;
                return InkWell(
                  onTap: () => setState(() => _indexSelectionne = i),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: estSelectionne
                          ? (estSombre ? AppTheme.darkPrimaryContainer : const Color(0xFFFBF6F0))
                          : (estSombre ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8F9FA)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: estSelectionne ? AppTheme.primary : couleurBordure,
                        width: estSelectionne ? 1.6 : 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFF4285F4),
                          child: Text(
                            compte['nom']![0],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                compte['nom']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: couleurTexte,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                compte['email']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: couleurAttenue,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (estSelectionne)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                        else
                          Icon(Icons.radio_button_unchecked_rounded, color: couleurAttenue, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (_messageErreur != null) ...[
              const SizedBox(height: 12),
              Text(
                _messageErreur!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.danger,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _enCours ? null : _lancerAuthentificationSimulee,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bissap,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _enCours
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GoogleGIcon(taille: 20),
                          SizedBox(width: 10),
                          Text(
                            "Continuer avec ce compte Google",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
