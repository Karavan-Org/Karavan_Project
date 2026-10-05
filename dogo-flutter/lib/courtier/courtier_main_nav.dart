import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'courtier_dashboard_screen.dart';
import 'gestion_convoi_screen.dart';
import 'portefeuille_courtier_screen.dart';
import 'courtier_profil_screen.dart';
import 'lancer_convoi_screen.dart';
import 'scanner_retrait_screen.dart';
import 'etape_transit_screen.dart';

/// Navigation principale Courtier avec barre d'onglets Figma et FAB central (+)
/// animé en arc de cercle avec effet de vague aquatique et prévisualisation au survol
class CourtierMainNav extends StatefulWidget {
  final int initialIndex;

  const CourtierMainNav({
    super.key,
    this.initialIndex = 0,
  });

  static void switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_CourtierMainNavState>();
    state?.setTabIndex(index);
  }

  @override
  State<CourtierMainNav> createState() => _CourtierMainNavState();
}

class _CourtierMainNavState extends State<CourtierMainNav>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _fabController;
  late AnimationController _waveLoopController;
  late Animation<double> _rotateAnimation;
  int? _hoveredArcIndex;

  final List<Widget> _screens = const [
    CourtierDashboardScreen(showBottomNav: false),
    GestionConvoiScreen(),
    PortefeuilleCourtierScreen(),
    CourtierProfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);

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
      if (status == AnimationStatus.forward || status == AnimationStatus.completed) {
        if (!_waveLoopController.isAnimating) {
          _waveLoopController.repeat();
        }
      } else if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed) {
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
    } else {
      _fabController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

          // 3. Déploiement des fonctionnalités Courtier en ARC DE CERCLE autour du bouton central (+)
          AnimatedBuilder(
            animation: Listenable.merge([_fabController, _waveLoopController]),
            builder: (context, child) {
              if (_fabController.value <= 0.01) return const SizedBox.shrink();

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

                        // Item 0 (Gauche - 152°) : Lancer Convoi
                        _buildArcButton(
                          index: 0,
                          total: 4,
                          angleDeg: 152.0,
                          radius: radius,
                          label: "Lancer",
                          subLabel: "Nouveau Convoi",
                          hoverTooltip: "🚀 Créer un Fret Aérien/Maritime",
                          icon: Icons.rocket_launch_rounded,
                          color: AppTheme.primary,
                          onTap: () {
                            _fabController.reverse();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LancerConvoiScreen()),
                            );
                          },
                        ),

                        // Item 1 (Haut-Gauche - 112°) : Scanner Retrait QR/PIN
                        _buildArcButton(
                          index: 1,
                          total: 4,
                          angleDeg: 112.0,
                          radius: radius,
                          label: "Scanner",
                          subLabel: "QR & PIN",
                          hoverTooltip: "📷 Scanner Code & Libérer Séquestre",
                          icon: Icons.qr_code_scanner_rounded,
                          color: const Color(0xFF2E7D32),
                          onTap: () {
                            _fabController.reverse();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ScannerRetraitScreen()),
                            );
                          },
                        ),

                        // Item 2 (Haut-Droite - 68°) : Mise à Jour Transit
                        _buildArcButton(
                          index: 2,
                          total: 4,
                          angleDeg: 68.0,
                          radius: radius,
                          label: "Transit",
                          subLabel: "Pointer Jalon",
                          hoverTooltip: "📍 Actualiser Étape & SMS Commerçants",
                          icon: Icons.cell_tower_rounded,
                          color: AppTheme.secondary,
                          onTap: () {
                            _fabController.reverse();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const EtapeTransitScreen()),
                            );
                          },
                        ),

                        // Item 3 (Droite - 28°) : Retirer Gains Commissions
                        _buildArcButton(
                          index: 3,
                          total: 4,
                          angleDeg: 28.0,
                          radius: radius,
                          label: "Gains",
                          subLabel: "Mobile Money",
                          hoverTooltip: "💼 Retirer Commissions Fret",
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFFE65100),
                          onTap: () {
                            _fabController.reverse();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PortefeuilleCourtierScreen()),
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
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Côté gauche : Tableau de bord + Convois
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      index: 0,
                      label: "Accueil",
                      activeIcon: Icons.home_rounded,
                      inactiveIcon: Icons.home_outlined,
                    ),
                    _buildNavItem(
                      index: 1,
                      label: "Convois",
                      activeIcon: Icons.local_shipping_rounded,
                      inactiveIcon: Icons.local_shipping_outlined,
                    ),
                  ],
                ),
              ),

              // Espace pour le FAB central (+)
              const SizedBox(width: 58),

              // Côté droit : Portefeuille + Profil
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      index: 2,
                      label: "Portefeuille",
                      activeIcon: Icons.account_balance_wallet_rounded,
                      inactiveIcon: Icons.account_balance_wallet_outlined,
                    ),
                    _buildNavItem(
                      index: 3,
                      label: "Profil",
                      activeIcon: Icons.business_center_rounded,
                      inactiveIcon: Icons.business_center_outlined,
                    ),
                  ],
                ),
              ),
            ],
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
    final double waveFloatY = math.sin((loopVal * 2 * math.pi) + (index * 1.5)) * 3.5 * progress;
    final double waveFloatX = math.cos((loopVal * 2 * math.pi) + (index * 1.5)) * 2.0 * progress;

    final double dx = (currentRadius * math.cos(rad)) + waveFloatX;
    final double dy = (-currentRadius * math.sin(rad)) + waveFloatY;

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
                            color: isHovered ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            width: isHovered ? 3.0 : 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: isHovered ? 0.65 : 0.40),
                              blurRadius: isHovered ? 18 : 10,
                              spreadRadius: isHovered ? 4 : 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: isHovered ? 26 : 23,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                                color: isHovered ? AppTheme.primary : AppTheme.textDark,
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
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
    final bool isSelected = (_currentIndex == index);

    return InkWell(
      onTap: () => setTabIndex(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? AppTheme.primary : const Color(0xFF8C7E74),
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : const Color(0xFF8C7E74),
              ),
            ),
          ],
        ),
      ),
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

    for (int i = 1; i <= 2; i++) {
      final ringProgress = (progress * 1.2 - (i * 0.25)).clamp(0.0, 1.0);
      if (ringProgress <= 0) continue;

      final paint = Paint()
        ..color = color.withValues(alpha: (1.0 - ringProgress) * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 - ringProgress);

      canvas.drawCircle(center, maxRadius * ringProgress, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

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
      final double rippleRadius = baseRadius + (wavePhase * (isHovered ? 18.0 : 12.0));
      final double rippleOpacity = (1.0 - wavePhase) * (isHovered ? 0.40 : 0.22);

      final paint = Paint()
        ..color = color.withValues(alpha: rippleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? 2.2 : 1.5;

      canvas.drawCircle(center, rippleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ItemWaveRipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isHovered != isHovered;
  }
}
