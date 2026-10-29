import '../widgets/tab_navigation_scope.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'mes_groupes_courtier_screen.dart';
import 'historique_courtier_screen.dart';
import 'parametres_courtier_screen.dart';
import 'notifications_courtier_screen.dart';
import '../widgets/mes_documents.dart';
import '../models/role_acteur.dart';
import 'assistance_courtier_screen.dart';
import '../services/auth_service.dart';
import '../widgets/avatar_profil_interactif.dart';
import '../widgets/bouton_bascule_theme.dart';
import '../services/notification_api_service.dart';

/// Écran du Profil Courtier fidèle à la maquette Figma Karavan (Frame "profil" Courtier)
/// Nom : Amadou Touré
/// Rôle : Courtier
/// Badge : Compte vérifié
/// Liste des 6 fonctionnalités associées à leurs écrans respectifs sans toucher aux TABS.
class CourtierProfilScreen extends StatefulWidget {
  const CourtierProfilScreen({super.key});

  @override
  State<CourtierProfilScreen> createState() => _CourtierProfilScreenState();
}

class _CourtierProfilScreenState extends State<CourtierProfilScreen> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.rechargerProfil();
    _chargerNonLues();
  }

  /// Notifications non lues, lues sur le serveur (un nouveau compte n'a que celle de bienvenue)
  int _nonLues = 0;

  Future<void> _chargerNonLues() async {
    final n = await NotificationApiService.instance.nombreNonLues();
    if (mounted) setState(() => _nonLues = n);
  }

  void _confirmerDeconnexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          "Déconnexion",
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(ctx)),
        ),
        content: Text(
          "Êtes-vous sûr de vouloir vous déconnecter de votre espace Courtier ?",
          style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Annuler", style: TextStyle(color: AppTheme.couleurTexteAttenue(ctx), fontWeight: FontWeight.w600)),
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
              backgroundColor: AppTheme.danger,
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                        MaterialPageRoute(builder: (_) => const ParametresCourtierScreen()),
                      );
                    },
                    tooltip: "Paramètres",
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // --- EN-TÊTE AVEC AVATAR ET IDENTITÉ COURTIER FIGMA ---
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Formes décoratives organiques douces en arrière-plan
                  Positioned(
                    top: -10,
                    child: CustomPaint(
                      painter: _CourtierOrganicBackgroundPainter(),
                      child: SizedBox(width: (MediaQuery.sizeOf(context).width - 40).clamp(0.0, 320.0).toDouble(), height: 160),
                    ),
                  ),

                  ValueListenableBuilder<UtilisateurProfil?>(
                    valueListenable: AuthService.instance.profilNotifier,
                    builder: (context, profil, _) {
                      final String nomAffiche = (profil?.nom.trim().isNotEmpty ?? false)
                          ? profil!.nom
                          : "Courtier Partenaire";
                      final String structureAffiche = profil?.structure ?? "";
                      final String telephoneAffiche = (profil?.telephone.isNotEmpty ?? false)
                          ? profil!.telephone
                          : "";

                      return Column(
                        children: [
                          // Avatar circulaire stylisé interactif
                          AvatarProfilInteractif(
                            photoUrl: profil?.photoUrl,
                            taille: 86,
                            customPainterDefaut: _CourtierAvatarPainter(),
                          ),

                          const SizedBox(height: 12),

                          // Nom
                          Text(
                            nomAffiche,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.couleurTexte(context),
                              letterSpacing: -0.2,
                            ),
                          ),

                          if (structureAffiche.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              structureAffiche,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.couleurTexteAttenue(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          if (telephoneAffiche.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              telephoneAffiche,
                              style: TextStyle(
                                fontSize: 12,
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
                                  color: AppTheme.couleurSurfaceDouce(context),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  "Courtier",
                                  style: TextStyle(
                                    color: AppTheme.couleurTexte(context),
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
                                  color: AppTheme.estSombre(context) ? AppTheme.darkOcreSurface : AppTheme.ocreClair,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.ocre.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: AppTheme.couleurAttention(context),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "Compte vérifié",
                                      style: TextStyle(
                                        color: AppTheme.couleurAttention(context),
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

              // --- CARTE MENU BLANCHE COMPRENANT LES 6 ITEMS FIGMA COURTIER ---
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.couleurCarte(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.couleurBordure(context)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x082C241E),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(type: MaterialType.transparency, borderRadius: BorderRadius.circular(22), clipBehavior: Clip.antiAlias, child: Column(
                  children: [
                    // Item 1 : Mes groupes
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.campaign_rounded,
                      label: "Mes groupes",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MesGroupesCourtierScreen()),
                        );
                      },
                    ),

                    // Item 2 : Historiques
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.assignment_outlined,
                      label: "Historiques",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HistoriqueCourtierScreen()),
                        );
                      },
                    ),

                    // Dossier de vérification réel (pièce d'identité, licence de transitaire)
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.folder_shared_outlined,
                      label: "Mes documents",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MesDocumentsScreen(role: RoleActeur.courtier)),
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
                          MaterialPageRoute(builder: (_) => const ParametresCourtierScreen()),
                        );
                      },
                    ),

                    // Item 4 : Notifications, avec le nombre réel de non lues
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.notifications_none_rounded,
                      label: "Notifications",
                      badgeText: _nonLues > 0 ? "$_nonLues" : null,
                      onTap: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const NotificationsCourtierScreen()))
                            .then((_) => _chargerNonLues());
                      },
                    ),

                    // Item 5 : Assistance
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.help_outline_rounded,
                      label: "Assistance",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AssistanceCourtierScreen()),
                        );
                      },
                    ),

                    // Item 6 : Déconnexion
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.logout_rounded,
                      label: "Déconnexion",
                      isLast: true,
                      onTap: () => _confirmerDeconnexion(context),
                    ),
                  ],
                )),
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
    String? badgeText,
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
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.terre,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppTheme.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textePale,
                size: 20,
              ),
            ],
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

/// Peintre pour les formes organiques de fond de l'en-tête profil courtier
class _CourtierOrganicBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppTheme.surfaceDouce.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = AppTheme.bordureForte.withValues(alpha: 0.60)
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

/// Peintre vectoriel pour l'avatar courtier (Style Amadou Touré Figma avec chemise jaune/moutarde et cravate/col blanc)
class _CourtierAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fond chaud
    final bgPaint = Paint()..color = AppTheme.bordureForte;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Vêtement (Haut jaune moutarde chaud d'après la maquette Amadou Touré)
    final clothesPaint = Paint()..color = AppTheme.ocre;
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

    // Cheveux soignés
    final hairPaint = Paint()..color = AppTheme.terre;
    final hairPath = Path()
      ..moveTo(w * 0.28, h * 0.42)
      ..quadraticBezierTo(w * 0.5, h * 0.16, w * 0.72, h * 0.42)
      ..quadraticBezierTo(w * 0.5, h * 0.32, w * 0.28, h * 0.42)
      ..close();
    canvas.drawPath(hairPath, hairPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
