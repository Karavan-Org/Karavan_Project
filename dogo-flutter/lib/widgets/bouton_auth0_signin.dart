import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/role_acteur.dart';
import '../screens/auth0_completer_profil_screen.dart';
import '../services/api/api_config.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Bouton officiel « Continuer avec Auth0 » pour l'authentification et l'inscription.
class BoutonAuth0SignIn extends StatelessWidget {
  final RoleActeur role;
  final String libelle;
  final VoidCallback? onAvantClic;
  final ValueChanged<String>? onTelephoneConfirme;

  const BoutonAuth0SignIn({
    super.key,
    required this.role,
    this.libelle = "Continuer avec Auth0",
    this.onAvantClic,
    this.onTelephoneConfirme,
  });

  Future<void> _declencherConnexionAuth0(BuildContext context) async {
    if (onAvantClic != null) onAvantClic!();

    // Ouvre la boîte de dialogue Auth0 (Universal Login web, test direct ou token)
    Auth0AuthModal.ouvrir(context: context, role: role);
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = AppTheme.estSombre(context);
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);

    return InkWell(
      onTap: () => _declencherConnexionAuth0(context),
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
            const Auth0ShieldIcon(taille: 22),
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

/// Logo vectoriel officiel Auth0 (Bouclier avec silhouette moderne)
class Auth0ShieldIcon extends StatelessWidget {
  final double taille;

  const Auth0ShieldIcon({super.key, this.taille = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: CustomPaint(
        painter: _Auth0ShieldLogoPainter(),
      ),
    );
  }
}

class _Auth0ShieldLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintFond = Paint()
      ..color = const Color(0xFFEB5424) // Orange officiel Auth0
      ..style = PaintingStyle.fill;

    // Forme de bouclier Auth0
    final path = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.90, h * 0.22)
      ..lineTo(w * 0.90, h * 0.55)
      ..cubicTo(w * 0.90, h * 0.78, w * 0.65, h * 0.95, w * 0.5, h * 0.98)
      ..cubicTo(w * 0.35, h * 0.95, w * 0.10, h * 0.78, w * 0.10, h * 0.55)
      ..lineTo(w * 0.10, h * 0.22)
      ..close();

    canvas.drawPath(path, paintFond);

    // Chevron intérieur blanc
    final paintChevron = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathChevron = Path()
      ..moveTo(w * 0.34, h * 0.44)
      ..lineTo(w * 0.50, h * 0.60)
      ..lineTo(w * 0.66, h * 0.44);

    canvas.drawPath(pathChevron, paintChevron);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Boîte de dialogue Auth0 permettant la connexion web officielle,
/// la saisie directe de jeton ou la sélection de profil démo instantané.
class Auth0AuthModal extends StatefulWidget {
  final RoleActeur role;

  const Auth0AuthModal({super.key, required this.role});

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
            child: Auth0AuthModal(role: role),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Auth0AuthModal(role: role),
    );
  }

  @override
  State<Auth0AuthModal> createState() => _Auth0AuthModalState();
}

class _Auth0AuthModalState extends State<Auth0AuthModal> {
  final TextEditingController _tokenController = TextEditingController();
  bool _enCours = false;
  String? _messageErreur;

  final List<Map<String, String>> _comptesDisponibles = const [
    {
      'nom': 'Salif Modibo Keïta',
      'email': 'salifmodibok@gmail.com',
      'sub': 'auth0|salif-modibo',
    },
    {
      'nom': 'Mamadou Touré (Grossiste)',
      'email': 'grossiste.toure@gmail.com',
      'sub': 'auth0|grossiste-toure',
    },
    {
      'nom': 'Ousmane Traoré (Courtier)',
      'email': 'courtier.traore@gmail.com',
      'sub': 'auth0|courtier-traore',
    },
    {
      'nom': 'Nouvelle Boutique (Inscription)',
      'email': 'nouveau.commercant@karavan.ml',
      'sub': 'auth0|nouveau-commercant-2026',
    },
  ];

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _ouvrirAuth0UniversalLogin() async {
    const domain = ApiConfig.auth0Domain;
    const clientId = ApiConfig.auth0ClientId;
    final audience = Uri.encodeComponent(ApiConfig.auth0Audience);
    final redirectUri = Uri.encodeComponent('http://localhost:3000');

    final url = Uri.parse(
      'https://$domain/authorize?client_id=$clientId&response_type=token%20id_token&redirect_uri=$redirectUri&scope=openid%20profile%20email&audience=$audience&nonce=karavan-${DateTime.now().millisecondsSinceEpoch}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _messageErreur = "Impossible d'ouvrir le navigateur pour Auth0.");
      }
    } catch (e) {
      setState(() => _messageErreur = "Erreur lors de l'ouverture d'Auth0 : $e");
    }
  }

  Future<void> _authentifierAvecToken(String token, String nom, String email) async {
    setState(() {
      _enCours = true;
      _messageErreur = null;
    });

    final nav = Navigator.of(context);

    try {
      final res = await AuthService.instance.authentifierAuth0(token);
      final statut = res['statut']?.toString();
      final String? jeton = res['jeton'] as String?;
      final bool estConnecte = statut == 'CONNECTE' || (jeton != null && jeton.isNotEmpty);

      if (!mounted) return;

      if (estConnecte) {
        nav.pop(); // Fermer la modale
        final profil = AuthService.instance.profilActuel;
        final roleEffectif = profil?.roleActeur ?? widget.role;

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
            builder: (_) => Auth0CompleterProfilScreen(
              jetonInscription: res['jetonInscription']?.toString() ?? '',
              sub: res['sub']?.toString(),
              email: res['email']?.toString() ?? email,
              emailVerified: res['emailVerified'] == true,
              nom: res['nom']?.toString() ?? nom,
              photoUrl: res['photoUrl']?.toString(),
              roleParDefaut: widget.role,
            ),
          ),
        );
      } else {
        setState(() => _messageErreur = res['message']?.toString() ?? "Réponse inattendue d'Auth0.");
      }
    } on ApiException catch (e) {
      setState(() => _messageErreur = e.messageComplet);
    } catch (e) {
      setState(() => _messageErreur = "Échec d'authentification Auth0 : $e");
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);

    return Container(
      decoration: BoxDecoration(
        color: couleurCarte,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: couleurBordure, width: 1.2),
        boxShadow: AppTheme.ombreDouce,
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Auth0ShieldIcon(taille: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Connexion avec Auth0",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: couleurTexte),
                    ),
                    Text(
                      "Identifiant : ${ApiConfig.auth0ClientId.substring(0, 8)}...",
                      style: TextStyle(fontSize: 12, color: couleurAttenue),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 1. Bouton officiel Web Universal Login
          ElevatedButton.icon(
            onPressed: _enCours ? null : _ouvrirAuth0UniversalLogin,
            icon: const Icon(Icons.open_in_browser_rounded, size: 20),
            label: const Text("Ouvrir la page de connexion Auth0"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEB5424),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: couleurBordure)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text("OU CHOISIR UN COMPTE TEST", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: couleurAttenue)),
              ),
              Expanded(child: Divider(color: couleurBordure)),
            ],
          ),
          const SizedBox(height: 12),

          // Liste des comptes test instantanés
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _comptesDisponibles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = _comptesDisponibles[i];
                final mockToken = "mock-auth0-token:${c['sub']}:${c['email']}:true:${c['nom']}:";
                return InkWell(
                  onTap: _enCours ? null : () => _authentifierAvecToken(mockToken, c['nom']!, c['email']!),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.couleurSurfaceDouce(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: couleurBordure),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFEB5424).withValues(alpha: 0.18),
                          child: Text(
                            c['nom']![0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEB5424)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['nom']!, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: couleurTexte)),
                              Text(c['email']!, style: TextStyle(fontSize: 12, color: couleurAttenue)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_messageErreur != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
              ),
              child: Text(_messageErreur!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

// Rétrocompatibilité
typedef BoutonGoogleSignIn = BoutonAuth0SignIn;
typedef GoogleAuthModal = Auth0AuthModal;
