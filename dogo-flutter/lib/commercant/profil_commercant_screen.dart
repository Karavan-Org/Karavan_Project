import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_navigation_scope.dart';
import 'mes_commandes_screen.dart';
import 'portefeuille_commercant_screen.dart';
import 'mes_favoris_screen.dart';
import 'notifications_commercant_screen.dart';
import 'aide_support_screen.dart';
import 'parametres_commercant_screen.dart';
import '../services/auth_service.dart';
import '../services/logistique_api_service.dart';
import '../models/niveau_commercant.dart';
import 'details_niveau_commercant_sheet.dart';
import 'favoris_service.dart';
import '../widgets/bouton_bascule_theme.dart';
import '../widgets/avatar_profil_interactif.dart';
import '../services/notification_api_service.dart';
import '../utils/format.dart';
import '../models/participation_model.dart';
import '../services/groupe_api_service.dart';

/// Écran du Profil Commerçant fidèle à la maquette Figma Dogo (Frame "profil")
/// Nom & Téléphone : issus de la session connectée (repli Hawa Dagno)
/// Badges : [Commerçant] [Niveau X (cliquable avec détail des avantages)]
/// Stats : Nb commandes réelles & économies estimées
/// Menus avec navigation dédiée vers leurs pages respectives.
class ProfilCommercantScreen extends StatefulWidget {
  const ProfilCommercantScreen({super.key});

  @override
  State<ProfilCommercantScreen> createState() => _ProfilCommercantScreenState();
}

class _ProfilCommercantScreenState extends State<ProfilCommercantScreen> {
  /// Commandes réelles du commerçant : 0 pour un nouveau compte (Niveau 1), jamais une valeur de maquette
  int _nbCommandes = 0;

  /// Notifications non lues, lues sur le serveur (un nouveau compte n'a que celle de bienvenue)
  int _nonLues = 0;

  Future<void> _chargerNonLues() async {
    final n = await NotificationApiService.instance.nombreNonLues();
    if (mounted) setState(() => _nonLues = n);
  }

  @override
  void initState() {
    super.initState();
    AuthService.instance.profilNotifier.addListener(_surProfilChange);
    AuthService.instance.rechargerProfil();
    _chargerCommandes();
    _chargerNonLues();
  }

  @override
  void dispose() {
    AuthService.instance.profilNotifier.removeListener(_surProfilChange);
    super.dispose();
  }

  void _surProfilChange() {
    if (mounted) setState(() {});
  }

  /// Total réellement payé : participations confirmées (le séquestre est constitué), lues sur le serveur
  double _totalAchats = 0;

  Future<void> _chargerCommandes() async {
    try {
      final resultats = await Future.wait<Object>([
        LogistiqueApiService.instance.mesCommandes(),
        GroupeApiService.instance.mesParticipations(),
      ]);
      if (!mounted) return;
      final commandes = resultats[0] as List;
      final participations = resultats[1] as List<ParticipationModel>;
      setState(() {
        _nbCommandes = commandes.length;
        _totalAchats = participations
            .where((p) => p.statut == 'CONFIRMEE')
            .fold<double>(0, (s, p) => s + p.montant);
      });
    } catch (_) {
      // Hors ligne : les compteurs restent à leur dernière valeur connue
    }
  }

  void _onClose(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      TabNavigationScope.switchToTab(context, 0);
    }
  }

  void _confirmerDeconnexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          "Déconnexion",
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
        content: Text(
          "Êtes-vous sûr de vouloir vous déconnecter de votre espace Commerçant ?",
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
    final niveauInfo = NiveauCommercant.calculer(_nbCommandes);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            children: [
              // --- BARRE SUPÉRIEURE (✕ à gauche, ⚙ à droite) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 26,
                      color: AppTheme.couleurTexte(context),
                    ),
                    onPressed: () => _onClose(context),
                    tooltip: "Retour",
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
                            MaterialPageRoute(builder: (_) => const ParametresCommercantScreen()),
                          );
                        },
                        tooltip: "Paramètres",
                      ),
                    ],
                  ),
                ],
              ),

              // --- EN-TÊTE AVEC FORMES ORGANIQUES, AVATAR ET BADGES ---
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Formes décoratives organiques en arrière-plan (feuilles/courbes beige chaud)
                  Positioned(
                    top: -10,
                    child: CustomPaint(
                      painter: _OrganicBackgroundPainter(),
                      child: SizedBox(width: (MediaQuery.sizeOf(context).width - 40).clamp(0.0, 320.0).toDouble(), height: 160),
                    ),
                  ),

                  ValueListenableBuilder<UtilisateurProfil?>(
                    valueListenable: AuthService.instance.profilNotifier,
                    builder: (context, profil, _) {
                      final String nomAffiche = (profil != null && profil.nom.trim().isNotEmpty)
                          ? profil.nom
                          : "Mon Compte Commerçant";
                      final String telephoneAffiche = (profil != null && profil.telephone.trim().isNotEmpty)
                          ? profil.telephone
                          : "";
                      final String? boutique = profil?.structure;

                      return Column(
                        children: [
                          const SizedBox(height: 6),
                          // Avatar interactif (caméra en direct ou galerie avec repli CustomPainter)
                          AvatarProfilInteractif(
                            photoUrl: profil?.photoUrl,
                            taille: 86,
                            customPainterDefaut: _MerchantAvatarPainter(),
                            onPhotoChangee: () {
                              if (mounted) setState(() {});
                            },
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

                          // Boutique / Structure
                          if (boutique != null && boutique.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.storefront_outlined, size: 14, color: AppTheme.couleurAttention(context)),
                                const SizedBox(width: 5),
                                Text(
                                  boutique,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.couleurAttention(context),
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

                          // Badges de rôle et de niveau
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.terre,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  "Commerçant",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                              // Badge interactif de Niveau
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    DetailsNiveauCommercantSheet.afficher(
                                      context,
                                      nbCommandes: _nbCommandes,
                                      onExplorer: () {
                                        FavorisService.instance.actualiserDepuisBackend();
                                        TabNavigationScope.switchToTab(context, 1);
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: niveauInfo.couleurBadge,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: niveauInfo.couleurBadge.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          niveauInfo.icone,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          niveauInfo.titre,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          size: 12,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ),
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

              const SizedBox(height: 22),

              // --- CARTE STATISTIQUES (commandes | économies) ---
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.couleurCarte(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.couleurBordure(context)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x082C241E),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Colonne gauche : nb commandes
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MesCommandesScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              Text(
                                "$_nbCommandes",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.couleurTexte(context),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "commandes",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.couleurTexteAttenue(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Séparateur vertical fin
                    Container(
                      height: 36,
                      width: 1,
                      color: AppTheme.couleurBordure(context),
                    ),

                    // Colonne droite : économies estimées
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PortefeuilleCommercantScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              Text(
                                formaterFcfa(_totalAchats),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.couleurTexte(context),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "d'achats payés",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.couleurTexteAttenue(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- CARTE MENU COMPRENANT LES 6 ITEMS FIGMA ---
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
                    // Item 1 : Mes commandes
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.receipt_long_outlined,
                      label: "Mes commandes",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MesCommandesScreen()),
                        );
                      },
                    ),

                    // Item 2 : Mon portefeuille
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: "Mon portefeuille",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PortefeuilleCommercantScreen()),
                        );
                      },
                    ),

                    // Item 3 : Mes favoris
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.favorite_border,
                      label: "Mes favoris",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MesFavorisScreen()),
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
                            .push(MaterialPageRoute(builder: (_) => const NotificationsCommercantScreen()))
                            .then((_) => _chargerNonLues());
                      },
                    ),

                    // Item 5 : Aide & support
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.support_agent_rounded,
                      label: "Aide & support",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AideSupportScreen()),
                        );
                      },
                    ),

                    // Item 6 : Paramètres
                    _buildFigmaMenuItem(
                      context: context,
                      icon: Icons.tune_rounded,
                      label: "Paramètres",
                      isLast: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ParametresCommercantScreen()),
                        );
                      },
                    ),
                  ],
                )),
              ),

              const SizedBox(height: 16),

              // --- BOUTON DÉCONNEXION EN BAS (FIGMA) ---
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _confirmerDeconnexion(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: AppTheme.couleurTexte(context), size: 20),
                        const SizedBox(width: 14),
                        Text(
                          "Déconnexion",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.couleurTexte(context),
                          ),
                        ),
                      ],
                    ),
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
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.couleurTexte(context),
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
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.couleurTexteAttenue(context).withValues(alpha: 0.6),
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

/// Peintre pour les formes organiques de fond de l'en-tête profil (Feuilles/Pétales douces Figma)
class _OrganicBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppTheme.surfaceDouce.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = AppTheme.bordureForte.withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;

    // Pétale / Forme douce gauche
    final pathLeft = Path()
      ..moveTo(size.width * 0.15, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.05, size.height * 0.85, size.width * 0.28, size.height * 0.95)
      ..quadraticBezierTo(size.width * 0.42, size.height * 0.98, size.width * 0.35, size.height * 0.5)
      ..close();
    canvas.drawPath(pathLeft, paint1);

    // Pétale / Forme douce droite
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

/// Peintre vectoriel pour l'avatar marchand (Style Hawa Dagno Figma avec kofi et tenue chaude)
class _MerchantAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fond chaud
    final bgPaint = Paint()..color = AppTheme.bordureForte;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Buste / Vêtement (Boubou marron chaud)
    final clothesPaint = Paint()..color = AppTheme.bissap;
    final clothesPath = Path()
      ..moveTo(w * 0.15, h)
      ..quadraticBezierTo(w * 0.25, h * 0.68, w * 0.5, h * 0.68)
      ..quadraticBezierTo(w * 0.75, h * 0.68, w * 0.85, h)
      ..close();
    canvas.drawPath(clothesPath, clothesPaint);

    // Col / Échancrure blanche
    final colPaint = Paint()..color = Colors.white;
    final colPath = Path()
      ..moveTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.5, h * 0.82)
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

    // Barbe soignée
    final beardPaint = Paint()..color = const Color(0xFF3E2312);
    final beardPath = Path()
      ..moveTo(w * 0.32, h * 0.48)
      ..quadraticBezierTo(w * 0.5, h * 0.70, w * 0.68, h * 0.48)
      ..quadraticBezierTo(w * 0.5, h * 0.60, w * 0.32, h * 0.48)
      ..close();
    canvas.drawPath(beardPath, beardPaint);

    // Kufi / Chapeau traditionnel (sombre élégant)
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
