import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'commercant_home_screen.dart';
import 'explorer_screen.dart';
import 'mes_commandes_screen.dart';
import 'profil_commercant_screen.dart';
import 'mes_favoris_screen.dart';
import 'suivi_colis_screen.dart';
import 'code_retrait_commercant_screen.dart';
import 'rejoindre_groupe_screen.dart';
import 'groupe_selection_service.dart';
import 'ouvrir_groupe_screen.dart';
import '../services/lien_groupe.dart';
import '../services/session_storage_service.dart';
import '../services/url_route_helper.dart';
import '../widgets/tab_navigation_scope.dart';

/// Navigation principale Commerçant reproduisant fidèlement la maquette Figma Dogo
/// avec animation FLUTTER FAB en ARC DE CERCLE (Radial / Semicircular Speed Dial)
/// et effet de vague / ondulation organique autour du bouton central (+) :
/// - Onglet 1 : Accueil (Vitrine des offres groupées et arrivages)
/// - Onglet 2 : Explorer (Recherche, filtres Chine/Turquie/Dubaï et catégories)
/// - Bouton Central (+) : FAB avec rotation (+) -> (✕) et déploiement en arc de cercle
/// - Onglet 3 : Commandes (Suivi des commandes en transit, prêtes et livrées)
/// - Onglet 4 : Profil (Boutique, Séquestre, Historique & Paramètres)
class CommercantMainNav extends StatefulWidget {
  final int initialIndex;

  const CommercantMainNav({
    super.key,
    this.initialIndex = 0,
  });

  static void switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_CommercantMainNavState>();
    state?.setTabIndex(index);
  }

  @override
  State<CommercantMainNav> createState() => _CommercantMainNavState();
}

class _CommercantMainNavState extends State<CommercantMainNav>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _fabController;
  late AnimationController _waveLoopController;
  late Animation<double> _rotateAnimation;
  int? _hoveredArcIndex;

  final List<Widget> _screens = const [
    CommercantHomeScreen(),
    ExplorerScreen(),
    MesCommandesScreen(),
    ProfilCommercantScreen(),
  ];

  @override
  void initState() {
    super.initState();
    SessionStorageService.instance.sauvegarderDernierEspace('commercant');
    definirRouteWeb('/commercant');
    _currentIndex = widget.initialIndex.clamp(0, 3);

    // Lien d'invitation reçu avant la connexion : on ouvre le groupe dès l'arrivée dans l'espace commerçant
    final enAttente = LienGroupe.enAttente;
    if (enAttente != null) {
      LienGroupe.enAttente = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => OuvrirGroupeScreen(groupeId: enAttente)));
        }
      });
    }

    // Contrôleur d'animation pour l'ouverture en arc de cercle avec effet d'onde
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 320),
    );

    // Contrôleur de boucle pour l'ondulation continue en vagues (animé uniquement menu ouvert pour économiser la batterie)
    _waveLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fabController.addStatusListener((status) {
      if (status == AnimationStatus.forward || status == AnimationStatus.completed) {
        if (!_waveLoopController.isAnimating) {
          _waveLoopController.repeat();
        }
      } else if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed) {
        _waveLoopController.stop();
      }
    });

    // Rotation du bouton central (+) de 0 à 45° pour former la croix (✕)
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
    } else {
      _fabController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabNavigationScope(
      onSwitchTab: setTabIndex,
      child: Scaffold(
      body: Stack(
        children: [
          // 1. Écrans principaux avec IndexedStack
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // 2. Arrière-plan semi-transparent estompé quand le menu FAB est déployé
          AnimatedBuilder(
            animation: _fabController,
            builder: (context, child) {
              if (_fabController.value == 0.0) return const SizedBox.shrink();
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

          // 3. Déploiement des fonctionnalités en ARC DE CERCLE autour du bouton central (+)
          AnimatedBuilder(
            animation: Listenable.merge([_fabController, _waveLoopController]),
            builder: (context, child) {
              if (_fabController.value <= 0.01) return const SizedBox.shrink();

              // Rayon de l'arc de cercle (distance entre le centre du FAB et les boutons)
              const double radius = 124.0;

              return Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
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
                          child: const SizedBox(width: 300, height: 180),
                        ),

                        // Item 0 (Gauche - 152°) : Rejoindre le groupe sélectionné en arrière-plan et passer au paiement
                        _buildArcButton(
                          index: 0,
                          total: 4,
                          angleDeg: 152.0,
                          radius: radius,
                          label: "Rejoindre",
                          subLabel: "Paiement",
                          hoverTooltip: "💳 Valider le Paiement Séquestre",
                          icon: Icons.shopping_cart_checkout_rounded,
                          color: const Color(0xFF2E7D32),
                          onTap: () {
                            _fabController.reverse();
                            final groupe = GroupeSelectionService.instance.groupeSelectionne;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RejoindreGroupeScreen(
                                  groupeId: groupe.id,
                                  varianteId: groupe.varianteId,
                                  variantesDisponibles: groupe.variantes,
                                  titre: groupe.titre,
                                  quantite: groupe.quantiteMinParCommercant,
                                  quantiteMin: groupe.quantiteMinParCommercant,
                                  taille: groupe.variantes.isNotEmpty
                                      ? groupe.variantes.first.libelleComplet
                                      : "",
                                  prixUnitaire: groupe.prixGroupe,
                                  courtierNom: groupe.courtierNom,
                                  imagePath: groupe.imagePath,
                                  paysOrigine: groupe.paysOrigine,
                                ),
                              ),
                            );
                          },
                        ),

                        // Item 1 (Haut-Gauche - 112°) : Suivi Colis (SuiviColisScreen avec jauge prescrite)
                        _buildArcButton(
                          index: 1,
                          total: 4,
                          angleDeg: 112.0,
                          radius: radius,
                          label: "Suivi Colis",
                          subLabel: "Jauge Étapes",
                          hoverTooltip: "🚚 Suivre la Jauge du Colis",
                          icon: Icons.local_shipping_rounded,
                          color: AppTheme.primary,
                          onTap: () {
                            _fabController.reverse();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SuiviColisScreen()),
                            );
                          },
                        ),

                        // Item 2 (Haut-Droite - 68°) : Retrait Sécurisé (CodeRetraitCommercantScreen avec QR & PIN)
                        _buildArcButton(
                          index: 2,
                          total: 4,
                          angleDeg: 68.0,
                          radius: radius,
                          label: "Retrait",
                          subLabel: "QR & PIN",
                          hoverTooltip: "🔑 Afficher mon Code QR & PIN",
                          icon: Icons.qr_code_2_rounded,
                          color: AppTheme.secondary,
                          onTap: () {
                            _fabController.reverse();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CodeRetraitCommercantScreen()),
                            );
                          },
                        ),

                        // Item 3 (Droite - 28°) : Favoris sauvegardés (MesFavorisScreen)
                        _buildArcButton(
                          index: 3,
                          total: 4,
                          angleDeg: 28.0,
                          radius: radius,
                          label: "Favoris",
                          subLabel: "Sauvegardes",
                          hoverTooltip: "❤️ Consulter mes Favoris",
                          icon: Icons.favorite_rounded,
                          color: const Color(0xFFE74C3C),
                          onTap: () {
                            _fabController.reverse();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MesFavorisScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // Bouton Central Flottant (+) avec rotation fluide et ondulation de vagues
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          final isExpanded = _fabController.value > 0.05;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Onde / Halo pulsant d'eau autour du bouton central
              if (isExpanded)
                CustomPaint(
                  painter: _WavePulsePainter(
                    progress: _fabController.value,
                    color: AppTheme.primary,
                  ),
                  child: const SizedBox(width: 84, height: 84),
                ),

              Container(
                height: 58,
                width: 58,
                margin: const EdgeInsets.only(top: 8),
                child: FloatingActionButton(
                  heroTag: 'fab-nav-commercant',
                  onPressed: _toggleFabMenu,
                  elevation: isExpanded ? 8 : 4,
                  backgroundColor: isExpanded ? const Color(0xFF4A3222) : AppTheme.primary,
                  shape: const CircleBorder(),
                  child: Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Barre de navigation inférieure conforme au design Figma
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        elevation: 16,
        color: Colors.white,
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 100) return const SizedBox(height: 64);
            return SizedBox(
              height: 64,
              child: Row(
                children: [
                  // Côté gauche : Accueil + Explorer
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildNavItem(
                            index: 0,
                            label: "Accueil",
                            activeIcon: Icons.home,
                            inactiveIcon: Icons.home_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildNavItem(
                            index: 1,
                            label: "Explorer",
                            activeIcon: Icons.explore,
                            inactiveIcon: Icons.explore_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Espace pour le FAB central (+)
                  const SizedBox(width: 52),

                  // Côté droit : Commandes + Profil
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildNavItem(
                            index: 2,
                            label: "Commandes",
                            activeIcon: Icons.shopping_bag,
                            inactiveIcon: Icons.shopping_bag_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildNavItem(
                            index: 3,
                            label: "Profil",
                            activeIcon: Icons.person,
                            inactiveIcon: Icons.person_outline,
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

    // Calcul de l'intervalle d'échelonnement temporel pour l'effet de vague successive d'ouverture
    final double start = (index * 0.10).clamp(0.0, 0.65);
    final double end = (start + 0.45).clamp(0.0, 1.0);

    final itemAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    final progress = itemAnimation.value;
    if (progress <= 0.01) return const SizedBox.shrink();

    // Conversion de l'angle en radians
    final double rad = angleDeg * math.pi / 180.0;

    // Effet d'ondulation radiale en vague : rebond sinusoïdal au sommet
    final double waveBounce = 0.12 * math.sin(progress * math.pi);
    final double currentRadius = radius * (progress + waveBounce);

    // Mouvement continu de vague flottante (oscillation aquatique sinusoïdale)
    final double loopVal = _waveLoopController.value;
    final double waveFloatY = math.sin((loopVal * 2 * math.pi) + (index * 1.5)) * 3.5 * progress;
    final double waveFloatX = math.cos((loopVal * 2 * math.pi) + (index * 1.5)) * 2.0 * progress;

    // Coordonnées trigonométriques cartésiennes avec composante de vague flottante
    final double dx = (currentRadius * math.cos(rad)) + waveFloatX;
    final double dy = (-currentRadius * math.sin(rad)) + waveFloatY;

    // Facteurs d'échelle et d'opacité réactifs au survol
    final double hoverScale = isHovered ? 1.25 : (isOtherHovered ? 0.90 : 1.0);
    final double finalOpacity = (progress * (isOtherHovered ? 0.55 : 1.0)).clamp(0.0, 1.0);

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
                  // Ondes et rides d'eau concentriques pulsantes autour du bouton
                  CustomPaint(
                    painter: _ItemWaveRipplePainter(
                      animationValue: loopVal,
                      color: color,
                      isHovered: isHovered,
                    ),
                    child: const SizedBox(width: 76, height: 76),
                  ),

                  // Contenu principal : Icône circulaire et étiquette
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bulle circulaire principale avec halo de lumière accentué au survol
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isHovered ? 54 : 50,
                        height: isHovered ? 54 : 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isHovered ? Border.all(color: Colors.white, width: 2.5) : null,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: isHovered ? 0.70 : 0.40),
                              blurRadius: isHovered ? 24 : 14,
                              spreadRadius: isHovered ? 4 : 0,
                              offset: const Offset(0, 4),
                            ),
                            if (isHovered)
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: isHovered ? 26 : 24,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Badge étiquette d'identification sous chaque bulle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isHovered ? 10 : 8,
                          vertical: isHovered ? 4 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: isHovered ? color : Colors.white,
                          borderRadius: BorderRadius.circular(isHovered ? 14 : 10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isHovered ? 0.25 : 0.12),
                              blurRadius: isHovered ? 10 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: isHovered ? 11 : 10.5,
                            fontWeight: FontWeight.w800,
                            color: isHovered ? Colors.white : color,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Capsule flottante de prévisualisation au survol (montre le choix avant le clic)
                  if (isHovered)
                    Positioned(
                      bottom: 82,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B1D14),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x38000000),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 7),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              hoverTooltip,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
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
    final bool isSelected = _currentIndex == index;
    final color = isSelected ? AppTheme.primary : AppTheme.textMuted;

    return InkWell(
      onTap: () {
        if (_fabController.isCompleted) {
          _fabController.reverse();
        }
        setState(() => _currentIndex = index);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Peintre de la trajectoire en arc de cercle avec effet d'onde et pointillés doux
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
    final rect = Rect.fromCircle(center: center, radius: radius);

    // L'arc va de 20° à 160° (en coordonnées trigonométriques au-dessus de l'horizon)
    // En Flutter Canvas : 0 rad = Est, pi rad = Ouest, pi/2 = Sud, -pi/2 = Nord.
    // L'arc au-dessus du centre commence à -pi * 0.9 (Ouest haut) et balaie vers l'Est haut.
    const startAngle = -math.pi * 0.90;
    final sweepAngle = (math.pi * 0.80) * progress;

    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.22 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcTrackPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Peintre pour l'onde pulsante circulaire autour du bouton (+)
class _WavePulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WavePulsePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Vague d'onde 1
    final waveRadius1 = 30.0 + (maxRadius - 30.0) * progress;
    final opacity1 = (1.0 - progress).clamp(0.0, 1.0) * 0.45;
    final paint1 = Paint()
      ..color = color.withValues(alpha: opacity1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(center, waveRadius1, paint1);

    // Vague d'onde 2 (déphasée)
    final progress2 = (progress - 0.2).clamp(0.0, 1.0) / 0.8;
    if (progress2 > 0) {
      final waveRadius2 = 30.0 + (maxRadius - 30.0) * progress2;
      final opacity2 = (1.0 - progress2).clamp(0.0, 1.0) * 0.28;
      final paint2 = Paint()
        ..color = color.withValues(alpha: opacity2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, waveRadius2, paint2);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Peintre pour les ondes et vagues d'eau concentriques autour de chaque élément de l'arc
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
    const baseRadius = 26.0;

    // Vague d'onde 1
    final wave1 = animationValue.clamp(0.0, 1.0);
    final r1 = baseRadius + (isHovered ? 20.0 : 12.0) * wave1;
    final op1 = (1.0 - wave1).clamp(0.0, 1.0) * (isHovered ? 0.55 : 0.28);
    final paint1 = Paint()
      ..color = color.withValues(alpha: op1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHovered ? 2.5 : 1.5;
    canvas.drawCircle(center, r1, paint1);

    // Vague d'onde 2 (déphasée pour un effet d'ondes continues)
    final wave2 = (animationValue + 0.5) % 1.0;
    final r2 = baseRadius + (isHovered ? 20.0 : 12.0) * wave2;
    final op2 = (1.0 - wave2).clamp(0.0, 1.0) * (isHovered ? 0.38 : 0.18);
    final paint2 = Paint()
      ..color = color.withValues(alpha: op2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHovered ? 2.0 : 1.2;
    canvas.drawCircle(center, r2, paint2);
  }

  @override
  bool shouldRepaint(covariant _ItemWaveRipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isHovered != isHovered;
  }
}
