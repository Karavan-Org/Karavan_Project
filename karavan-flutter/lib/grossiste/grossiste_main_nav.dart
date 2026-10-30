import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'grossiste_dashboard_screen.dart';
import 'grossiste_catalogue_screen.dart';
import 'grossiste_commandes_screen.dart';
import 'grossiste_profil_screen.dart';
import 'ajouter_produit_screen.dart';
import 'creer_groupe_grossiste_screen.dart';
import 'selection_produit_grossiste.dart';
import 'validation_stock_grossiste_screen.dart';
import 'suivi_colis_grossiste_screen.dart';
import '../services/session_storage_service.dart';
import '../services/auth_service.dart';
import '../services/url_route_helper.dart';
import '../widgets/onglet_navigation.dart';
import '../widgets/tab_navigation_scope.dart';
import 'didacticiel_grossiste_guide.dart';
import 'grossiste_acces.dart';
import '../models/role_acteur.dart';
import '../widgets/didacticiel_guide_overlay.dart';

/// Navigation principale Grossiste avec barre d'onglets Figma et FAB central (+)
/// animé en arc de cercle avec effet de vague aquatique et prévisualisation au survol
class GrossisteMainNav extends StatefulWidget {
  final int initialIndex;

  const GrossisteMainNav({
    super.key,
    this.initialIndex = 0,
  });

  static void switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_GrossisteMainNavState>();
    state?.setTabIndex(index);
  }

  /// Permet de lancer ou relancer le didacticiel interactif guidé depuis n'importe quel écran
  static void lancerGuide(BuildContext context) {
    final state = context.findAncestorStateOfType<_GrossisteMainNavState>();
    state?.demarrerGuide();
  }

  @override
  State<GrossisteMainNav> createState() => _GrossisteMainNavState();
}

class _GrossisteMainNavState extends State<GrossisteMainNav>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _fabController;
  late AnimationController _waveLoopController;
  late Animation<double> _rotateAnimation;
  int? _hoveredArcIndex;
  bool _afficherGuide = false;

  void demarrerGuide() {
    if (mounted) {
      setState(() {
        _currentIndex = 0;
        _afficherGuide = true;
      });
    }
  }

  final List<Widget> _screens = const [
    GrossisteDashboardScreen(showFab: false),
    GrossisteCatalogueScreen(),
    GrossisteCommandesScreen(),
    GrossisteProfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    SessionStorageService.instance.sauvegarderDernierEspace('grossiste');
    definirRouteWeb('/grossiste');
    _currentIndex = widget.initialIndex.clamp(0, 3);

    // Vérification de la première connexion pour afficher le didacticiel guidé interactif
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var tel = AuthService.instance.profilActuel?.telephone;
      var uid = AuthService.instance.profilActuel?.id;
      if (tel == null || tel.isEmpty || uid == null) {
        final profil = await SessionStorageService.instance.lireProfil();
        tel ??= profil?.telephone;
        uid ??= profil?.id;
      }
      tel ??= "defaut";
      final vu = await SessionStorageService.instance
          .aDejaVuGuide('grossiste', tel, utilisateurId: uid);
      if (!vu && mounted) {
        setState(() => _afficherGuide = true);
      }
    });

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 320),
    );

    _waveLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fabController.addStatusListener((status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.completed) {
        if (!_waveLoopController.isAnimating) {
          _waveLoopController.repeat();
        }
      } else if (status == AnimationStatus.reverse ||
          status == AnimationStatus.dismissed) {
        _waveLoopController.stop();
      }
    });

    _rotateAnimation = Tween<double>(begin: 0.0, end: math.pi / 4).animate(
      CurvedAnimation(
        parent: _fabController,
        curve: Curves.easeInOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _waveLoopController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void setTabIndex(int index) {
    if (_fabController.isCompleted) {
      _fabController.reverse();
    }
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  void _toggleFabMenu() {
    if (_fabController.isCompleted) {
      _fabController.reverse();
      return;
    }
    // Un produit est sélectionné dans « Mon catalogue actif » : le (+) crée directement son groupe
    final produit = SelectionProduitGrossiste.produit.value;
    if (produit != null && _currentIndex == 0) {
      _creerGroupe(produit);
      return;
    }
    _fabController.forward();
  }

  void _creerGroupe(Map<String, dynamic>? produit) {
    SelectionProduitGrossiste.effacer();
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => CreerGroupeGrossisteScreen(produit: produit)),
    );
  }

  /// RG-03 : l'espace ne s'ouvre qu'à un compte actif, quel que soit le chemin pour y arriver
  @override
  Widget build(BuildContext context) => GardeCompteActif(
        role: RoleActeur.grossiste,
        child: PorteeCiblesDidacticiel(
            cibles: _ciblesDidacticiel,
            child: Builder(builder: _construireEspace)),
      );

  /// Clés propres à cet espace pour le didacticiel (jamais partagées avec un autre espace)
  final _ciblesDidacticiel = CiblesDidacticiel();

  Widget _construireEspace(BuildContext context) {
    return TabNavigationScope(
      onSwitchTab: setTabIndex,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppTheme.couleurFond(context),
            body: Stack(
              children: [
                // 1. Écrans principaux avec IndexedStack (tickers suspendus sur onglets masqués)
                IndexedStack(
                  index: _currentIndex,
                  children: [
                    for (int i = 0; i < _screens.length; i++)
                      TickerMode(
                        enabled: _currentIndex == i,
                        child: _screens[i],
                      ),
                  ],
                ),

                // 2. Arrière-plan semi-transparent estompé quand le menu FAB est déployé
                AnimatedBuilder(
                  animation: _fabController,
                  builder: (context, child) {
                    if (_fabController.value == 0.0) {
                      return const SizedBox.shrink();
                    }
                    return GestureDetector(
                      onTap: _toggleFabMenu,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 0.48 * _fabController.value,
                        ),
                      ),
                    );
                  },
                ),

                // 3. Déploiement des fonctionnalités Grossiste en ARC DE CERCLE autour du bouton central (+)
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_fabController, _waveLoopController]),
                  builder: (context, child) {
                    if (_fabController.value <= 0.01) {
                      return const SizedBox.shrink();
                    }

                    const double radius = 136.0;

                    return Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: 340,
                              height: 220,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // Trait d'arc de cercle lumineux en arrière-plan
                                  CustomPaint(
                                    painter: _ArcTrackPainter(
                                      progress: _fabController.value,
                                      radius: radius,
                                      primaryColor: AppTheme.primary,
                                    ),
                                    child:
                                        const SizedBox(width: 300, height: 180),
                                  ),

                                  // Item 0 (Gauche - 152°) : Ajouter Produit
                                  _buildArcButton(
                                    index: 0,
                                    total: 5,
                                    angleDeg: 160.0,
                                    radius: radius,
                                    label: "Produit",
                                    subLabel: "Nouveau",
                                    hoverTooltip:
                                        "📦 Créer & Publier un Article",
                                    icon: Icons.add_photo_alternate_rounded,
                                    color: AppTheme.primary,
                                    onTap: () {
                                      _fabController.reverse();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AjouterProduitScreen()),
                                      );
                                    },
                                  ),

                                  // Item 1 (Haut-Gauche - 112°) : Créer Groupe d'Achat
                                  _buildArcButton(
                                    index: 1,
                                    total: 5,
                                    angleDeg: 125.0,
                                    radius: radius,
                                    label: "Groupe",
                                    subLabel: "Créer",
                                    hoverTooltip: "👥 Lancer un groupe d'achat",
                                    icon: Icons.group_add_rounded,
                                    color: AppTheme.olive,
                                    onTap: () {
                                      _fabController.reverse();
                                      _creerGroupe(SelectionProduitGrossiste
                                          .produit.value);
                                    },
                                  ),

                                  // Item 2 (Haut-Droite - 68°) : Valider Disponibilité RG-18
                                  _buildArcButton(
                                    index: 2,
                                    total: 5,
                                    angleDeg: 90.0,
                                    radius: radius,
                                    label: "Stock",
                                    subLabel: "RG-18 (24h)",
                                    hoverTooltip:
                                        "⏳ Valider Disponibilité Stock",
                                    icon: Icons.fact_check_rounded,
                                    color: AppTheme.secondary,
                                    onTap: () {
                                      _fabController.reverse();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ValidationStockGrossisteScreen()),
                                      );
                                    },
                                  ),

                                  // Item 4 (Droite - 20°) : Suivi du colis (chaque étape validée notifie l'administrateur)
                                  _buildArcButton(
                                    index: 4,
                                    total: 5,
                                    angleDeg: 20.0,
                                    radius: radius,
                                    label: "Suivi",
                                    subLabel: "Colis",
                                    hoverTooltip:
                                        "📍 Valider les étapes du colis",
                                    icon: Icons.location_on_rounded,
                                    color: AppTheme.bissapProfond,
                                    onTap: () {
                                      _fabController.reverse();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const SuiviColisGrossisteScreen()),
                                      );
                                    },
                                  ),

                                  // Item 3 (Droite - 55°) : Expédier Lot au Transitaire
                                  _buildArcButton(
                                    index: 3,
                                    total: 5,
                                    angleDeg: 55.0,
                                    radius: radius,
                                    label: "Expédier",
                                    subLabel: "Mes lots",
                                    hoverTooltip:
                                        "🚚 Lots à préparer pour le courtier",
                                    icon: Icons.local_shipping_rounded,
                                    color: AppTheme.olive,
                                    // Les lots réels (à préparer / expédiés) sont dans l'onglet « Lots & Ventes »
                                    onTap: () => setTabIndex(2),
                                  ),
                                ],
                              ),
                            )),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Bouton Central Flottant (+) avec rotation fluide et ondulation de vagues
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            floatingActionButton: AnimatedBuilder(
              animation: _fabController,
              builder: (context, child) {
                final isExpanded = _fabController.value > 0.05;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 58,
                      width: 58,
                      margin: const EdgeInsets.only(top: 8),
                      child: FloatingActionButton(
                        key: _ciblesDidacticiel.fabCentral,
                        heroTag: 'fab-nav-grossiste',
                        onPressed: _toggleFabMenu,
                        elevation: isExpanded ? 8 : 4,
                        backgroundColor: isExpanded
                            ? AppTheme.bissapProfond
                            : AppTheme.primary,
                        shape: const CircleBorder(),
                        child: Transform.rotate(
                          angle: _rotateAnimation.value,
                          // Produit sélectionné sur l'accueil : le (+) annonce la création de son groupe
                          child: ValueListenableBuilder<Map<String, dynamic>?>(
                            valueListenable: SelectionProduitGrossiste.produit,
                            builder: (_, produit, __) => Icon(
                              produit != null &&
                                      _currentIndex == 0 &&
                                      !isExpanded
                                  ? Icons.group_add_rounded
                                  : Icons.add,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Barre de navigation inférieure conforme au design Figma
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppTheme.couleurBandeauNavigation(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.estSombre(context)
                        ? Colors.black.withValues(alpha: 0.35)
                        : const Color(0x332C241E),
                    blurRadius: 14,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 100) {
                      return const SizedBox(height: 64);
                    }
                    return SizedBox(
                      height: 64,
                      child: Row(
                        children: [
                          // Côté gauche : Tableau de bord + Catalogue
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildNavItem(
                                    index: 0,
                                    label: "Accueil",
                                    activeIcon: Icons.dashboard_rounded,
                                    inactiveIcon: Icons.dashboard_outlined,
                                  ),
                                ),
                                Expanded(
                                  child: _buildNavItem(
                                    index: 1,
                                    label: "Catalogue",
                                    activeIcon: Icons.inventory_2_rounded,
                                    inactiveIcon: Icons.inventory_2_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Espace pour le FAB central (+)
                          const SizedBox(width: 52),

                          // Côté droit : Lots/Commandes + Profil
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildNavItem(
                                    index: 2,
                                    label: "Lots & Ventes",
                                    activeIcon: Icons.local_shipping_rounded,
                                    inactiveIcon: Icons.local_shipping_outlined,
                                  ),
                                ),
                                Expanded(
                                  child: _buildNavItem(
                                    index: 3,
                                    label: "Profil",
                                    activeIcon: Icons.storefront_rounded,
                                    inactiveIcon: Icons.storefront_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_afficherGuide)
            Positioned.fill(
              child: DidacticielGrossisteGuide(
                onTermine: () {
                  if (mounted) setState(() => _afficherGuide = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Construit un bouton positionné sur l'arc de cercle avec onde de propagation,
  /// effet de vague aquatique continue et prévisualisation interactive au survol
  Widget _buildArcButton({
    required int index,
    required int total,
    required double angleDeg,
    required double radius,
    required String label,
    required String subLabel,
    required String hoverTooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isHovered = (_hoveredArcIndex == index);
    final bool isOtherHovered = (_hoveredArcIndex != null && !isHovered);

    final double start = (index * 0.10).clamp(0.0, 0.65);
    final double end = (start + 0.45).clamp(0.0, 1.0);

    final itemAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    final progress = itemAnimation.value;
    if (progress <= 0.01) return const SizedBox.shrink();

    final double rad = angleDeg * math.pi / 180.0;
    final double waveBounce = 0.12 * math.sin(progress * math.pi);
    final double currentRadius = radius * (progress + waveBounce);

    final double loopVal = _waveLoopController.value;
    final double waveFloatY =
        math.sin((loopVal * 2 * math.pi) + (index * 1.5)) * 3.5 * progress;
    final double waveFloatX =
        math.cos((loopVal * 2 * math.pi) + (index * 1.5)) * 2.0 * progress;

    final double dx = (currentRadius * math.cos(rad)) + waveFloatX;
    final double dy = (-currentRadius * math.sin(rad)) + waveFloatY;

    final double hoverScale = isHovered ? 1.25 : (isOtherHovered ? 0.90 : 1.0);
    final double finalOpacity =
        (progress * (isOtherHovered ? 0.55 : 1.0)).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: progress.clamp(0.0, 1.1) * hoverScale,
        child: Opacity(
          opacity: finalOpacity,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredArcIndex = index),
            onExit: (_) => setState(() => _hoveredArcIndex = null),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: _ItemWaveRipplePainter(
                      animationValue: loopVal,
                      color: color,
                      isHovered: isHovered,
                    ),
                    child: const SizedBox(width: 76, height: 76),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isHovered ? 54 : 50,
                        height: isHovered ? 54 : 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHovered
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.9),
                            width: isHovered ? 3.0 : 2.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 12,
                              
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            color: AppTheme.texteSur(color),
                            size: isHovered ? 26 : 23,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isHovered
                                    ? AppTheme.primary
                                    : AppTheme.textDark,
                              ),
                            ),
                            Text(
                              subLabel,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isHovered)
                    Positioned(
                      top: -38,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isHovered ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.terre,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                hoverTooltip,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    return OngletNavigation(
      label: label,
      activeIcon: activeIcon,
      inactiveIcon: inactiveIcon,
      selectionne: _currentIndex == index,
      onTap: () => setTabIndex(index),
    );
  }
}

/// Peintre de l'arc de cercle guide en pointillés fins
class _ArcTrackPainter extends CustomPainter {
  final double progress;
  final double radius;
  final Color primaryColor;

  _ArcTrackPainter({
    required this.progress,
    required this.radius,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05) return;

    final center = Offset(size.width / 2, size.height);
    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.28 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    final double sweep = (math.pi * 0.72) * progress;
    const double startAngle = -math.pi * 0.86;

    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcTrackPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.radius != radius;
  }
}

/// Onde pulsante concentrique d'eau autour du bouton central (+)
/// Peintre d'ondes aquatiques concentriques continues autour de chaque item de l'arc
class _ItemWaveRipplePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isHovered;

  _ItemWaveRipplePainter({
    required this.animationValue,
    required this.color,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = isHovered ? 28.0 : 25.0;

    for (int i = 0; i < 2; i++) {
      final double wavePhase = (animationValue + (i * 0.5)) % 1.0;
      final double rippleRadius =
          baseRadius + (wavePhase * (isHovered ? 18.0 : 12.0));
      final double rippleOpacity =
          (1.0 - wavePhase) * (isHovered ? 0.40 : 0.22);

      final paint = Paint()
        ..color = color.withValues(alpha: rippleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? 2.2 : 1.5;

      canvas.drawCircle(center, rippleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ItemWaveRipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isHovered != isHovered;
  }
}
