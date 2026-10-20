import '../widgets/tab_navigation_scope.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'mes_groupes_grossiste_screen.dart';
import 'historique_grossiste_screen.dart';
import 'parametres_grossiste_screen.dart';
import 'documents_grossiste_screen.dart';
import 'assistance_grossiste_screen.dart';
import 'portefeuille_grossiste_screen.dart';
import 'grossiste_main_nav.dart';
import '../services/auth_service.dart';
import '../widgets/avatar_profil_interactif.dart';
import '../widgets/bouton_bascule_theme.dart';

/// Écran du Profil Grossiste fidèle à la maquette Figma Dogo (Frame "profil" Grossiste)
/// Nom : Aliou Traoré
/// Rôle : Grossiste
/// Badge : Compte vérifié
/// Liste des 7 fonctionnalités associées à leurs écrans respectifs.
/// Liste des 7 fonctionnalités associées à leurs écrans respectifs.
class GrossisteProfilScreen extends StatefulWidget {
  const GrossisteProfilScreen({super.key});

  @override
  State<GrossisteProfilScreen> createState() => _GrossisteProfilScreenState();
}

class _GrossisteProfilScreenState extends State<GrossisteProfilScreen> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.rechargerProfil();
  }

  void _confirmerDeconnexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          "Déconnexion",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
        content: Text(
          "Êtes-vous sûr de vouloir vous déconnecter de votre espace Grossiste ?",
          style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Annuler", style: TextStyle(color: AppTheme.couleurTexteAttenue(context), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              AuthService.instance.deconnecter();
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/onboarding',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Se déconnecter", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          child: Column(
            children: [
              // Barre d'actions rapides (Mode sombre/clair & Paramètres)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
                    tooltip: "Retour",
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        TabNavigationScope.switchToTab(context, 0);
                      }
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BoutonBasculeTheme(compact: true),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, size: 24, color: AppTheme.couleurTexte(context)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ParametresGrossisteScreen()),
                      );
                    },
                    tooltip: "Paramètres",
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // --- EN-TÊTE AVEC AVATAR ET IDENTITÉ GROSSISTE FIGMA ---
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Formes décoratives organiques douces en arrière-plan
                  Positioned(
                    top: -10,
                    child: CustomPaint(
                      painter: _GrossisteOrganicBackgroundPainter(),
                      child: const SizedBox(width: 320, height: 160),
                    ),
                  ),

                  ValueListenableBuilder<UtilisateurProfil?>(
                    valueListenable: AuthService.instance.profilNotifier,
                    builder: (context, profil, _) {
                      final String nomAffiche = (profil?.nom.trim().isNotEmpty ?? false)
                          ? profil!.nom
                          : "Mon Compte Grossiste";
                      final String telephoneAffiche = (profil?.telephone.trim().isNotEmpty ?? false)
                          ? profil!.telephone
                          : "";
                      final String? entreprise = profil?.structure;

                      return Column(
                        children: [
                          // Avatar circulaire stylisé interactif
                          AvatarProfilInteractif(
                            photoUrl: profil?.photoUrl,
                            taille: 86,
                            customPainterDefaut: _GrossisteAvatarPainter(),
                          ),

                          const SizedBox(height: 12),

                          // Nom
                          Text(
                            nomAffiche,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.couleurTexte(context),
                              letterSpacing: -0.2,
                            ),
                          ),

                          // Entreprise / Boutique
                          if (entreprise != null && entreprise.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.business_outlined, size: 14, color: AppTheme.couleurAccent(context)),
                                const SizedBox(width: 5),
                                Text(
                                  entreprise,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.couleurAccent(context),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Téléphone
                          if (telephoneAffiche.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              telephoneAffiche,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.couleurTexteAttenue(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // Badges Rôle & Vérification
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2832),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  "Grossiste",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Badge doré "Compte vérifié"
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9E6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5A100).withValues(alpha: 0.35)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: Color(0xFFD48800),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "Compte vérifié",
                                      style: TextStyle(
                                        color: Color(0xFFB37400),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // --- CARTE MENU BLANCHE COMPRENANT LES 7 ITEMS FIGMA ---
              // Le fond blanc est porté par un Material (et non le Container) : les ListTile y dessinent leurs effets
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEFE9E0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0846321E),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: AppTheme.couleurCarte(context),
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Item 1 : Mes groupes
                      _buildFigmaMenuItem(
                        context: context,
                        icon: Icons.campaign_rounded,
                        label: "Mes groupes",
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MesGroupesGrossisteScreen()),
                          );
                        },
                      ),

                      // Item 2 : Historiques
                      _buildFigmaMenuItem(
                        context: context,
                        icon: Icons.receipt_long_outlined,
                        label: "Historiques",
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HistoriqueGrossisteScreen()),
                          );
                        },
                      ),

                      // Item 3 : Paramètres
                      _buildFigmaMenuItem(
                        context: context,
                        icon: Icons.tune_rounded,
                        label: "Paramètres",
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ParametresGrossisteScreen()),
                          );
                        },
                      ),

                      // Item 4 : Mes documents
                      _buildFigmaMenuItem(
                        context: context,
                        icon: Icons.description_outlined,
                        label: "Mes documents",
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DocumentsGrossisteScreen()),
                          );
                        },
                      ),

                      // Item 5 : Assistance
                      _buildFigmaMenuItem(
                        context: context,
                        icon: Icons.help_outline_rounded,
                        label: "Assistance",
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AssistanceGrossisteScreen()),
                          );
                        },
                      ),

                      // Item : Didacticiel guidé
                      _buildFigmaMenuItem(
                        context: context,
                        icon: Icons.school_outlined,
                        label: "Guide de l'application",
                        onTap: () {
                          GrossisteMainNav.lancerGuide(context);
                        },
                      ),

                      // Item 6 : Mon portefeuille
                      _buildFigmaMenuItem(
                        context: context,
                        icon: Icons.account_balance_wallet_outlined,
                        label: "Mon portefeuille",
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PortefeuilleGrossisteScreen()),
                          );
                        },
                      ),

                      // Item 7 : Déconnexion
                      _buildFigmaMenuItem(
                        context: context,
                        icon: Icons.logout_rounded,
                        label: "Déconnexion",
                        isLast: true,
                        onTap: () => _confirmerDeconnexion(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Élément de menu individuel fidèle au style Figma
  Widget _buildFigmaMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    bool isLast = false,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.couleurSurfaceDouce(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppTheme.couleurAccent(context),
              size: 19,
            ),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.couleurTexte(context),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.couleurTexteAttenue(context).withValues(alpha: 0.6),
            size: 20,
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            color: AppTheme.couleurBordure(context),
          ),
      ],
    );
  }
}

/// Peintre pour les formes organiques de fond de l'en-tête profil grossiste
class _GrossisteOrganicBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFF4ECE3).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = const Color(0xFFEEDFCF).withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;

    final pathLeft = Path()
      ..moveTo(size.width * 0.15, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.05, size.height * 0.85, size.width * 0.28, size.height * 0.95)
      ..quadraticBezierTo(size.width * 0.42, size.height * 0.98, size.width * 0.35, size.height * 0.5)
      ..close();
    canvas.drawPath(pathLeft, paint1);

    final pathRight = Path()
      ..moveTo(size.width * 0.82, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.95, size.height * 0.70, size.width * 0.78, size.height * 0.95)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.98, size.width * 0.68, size.height * 0.45)
      ..close();
    canvas.drawPath(pathRight, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Peintre vectoriel pour l'avatar grossiste (Style Aliou Traoré Figma avec chemise jaune/moutarde et chapeau)
class _GrossisteAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fond chaud
    final bgPaint = Paint()..color = const Color(0xFFE8DCCF);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Vêtement (Haut jaune moutarde chaud d'après la maquette Aliou Traoré)
    final clothesPaint = Paint()..color = const Color(0xFFE5A100);
    final clothesPath = Path()
      ..moveTo(w * 0.15, h)
      ..quadraticBezierTo(w * 0.25, h * 0.68, w * 0.5, h * 0.68)
      ..quadraticBezierTo(w * 0.75, h * 0.68, w * 0.85, h)
      ..close();
    canvas.drawPath(clothesPath, clothesPaint);

    // Col blanc
    final colPaint = Paint()..color = Colors.white;
    final colPath = Path()
      ..moveTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.5, h * 0.80)
      ..lineTo(w * 0.56, h * 0.68)
      ..close();
    canvas.drawPath(colPath, colPaint);

    // Cou
    final skinPaint = Paint()..color = const Color(0xFF7A4A28);
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.58), width: w * 0.22, height: h * 0.25),
      const Radius.circular(6),
    );
    canvas.drawRRect(neckRect, skinPaint);

    // Tête / Visage
    final headRect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.44), width: w * 0.44, height: h * 0.48);
    canvas.drawOval(headRect, skinPaint);

    // Chapeau / Capuchon (sombre élégant)
    final hatPaint = Paint()..color = const Color(0xFF2C241E);
    final hatPath = Path()
      ..moveTo(w * 0.28, h * 0.42)
      ..quadraticBezierTo(w * 0.5, h * 0.16, w * 0.72, h * 0.42)
      ..quadraticBezierTo(w * 0.5, h * 0.36, w * 0.28, h * 0.42)
      ..close();
    canvas.drawPath(hatPath, hatPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
