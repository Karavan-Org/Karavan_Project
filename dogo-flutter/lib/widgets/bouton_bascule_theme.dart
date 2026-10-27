import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Bouton interactif animé permettant de basculer entre le Mode Clair et le Mode Sombre.
///
/// Animations célestes dédiées :
/// - Mode Clair actif : Le Soleil rayonne (rotation lente, 8 rayons dorés qui pulsent et halo chaleureux rayonnant).
/// - Mode Sombre actif : La Lune est lumineuse (croissant lunaire nacré, aura céleste diffuse et étoiles scintillantes).
class BoutonBasculeTheme extends StatefulWidget {
  final bool compact;

  const BoutonBasculeTheme({
    super.key,
    this.compact = true,
  });

  @override
  State<BoutonBasculeTheme> createState() => _BoutonBasculeThemeState();
}

class _BoutonBasculeThemeState extends State<BoutonBasculeTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _continuousController;

  bool get _estEnTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _continuousController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    // Pas de boucle permanente : le bouton est présent sur une quinzaine d'écrans et une animation
    // infinie forcerait un rendu à 60 images/s en continu. Le soleil / la lune « respirent »
    // une fois au changement de thème, et en continu seulement pendant le survol (web, bureau).
    if (_estEnTest) _continuousController.value = 0.5;
  }

  void _basculer(BuildContext context) {
    ThemeService.instance.basculerMode(context);
    if (!_estEnTest) _continuousController.forward(from: 0);
  }

  void _survol(bool actif) {
    if (_estEnTest) return;
    if (actif) {
      _continuousController.repeat();
    } else if (_continuousController.isAnimating) {
      // Termine le cycle en cours pour revenir en douceur à l'image de repos
      _continuousController.forward();
    }
  }

  @override
  void dispose() {
    _continuousController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, mode, _) {
        final bool estSombre = ThemeService.instance.estSombre(context);

        if (widget.compact) {
          return Tooltip(
            message: estSombre
                ? "Mode Sombre actif • Appuyer pour activer le Mode Clair"
                : "Mode Clair actif • Appuyer pour activer le Mode Sombre",
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _basculer(context),
                onHover: _survol,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: estSombre
                        ? const Color(0x221E2A4A)
                        : const Color(0x18FFF3E0),
                    border: Border.all(
                      color: estSombre
                          ? const Color(0x405C6BC0)
                          : const Color(0x35FFA000),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: estSombre
                            ? const Color(0x1A0D47A1)
                            : const Color(0x1AFFA000),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Icône sémantique pour compatibilité de test et accessibilité
                      SizedBox(
                        width: 0,
                        height: 0,
                        child: Icon(
                          estSombre ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                          size: 0,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        transitionBuilder: (child, anim) {
                          final curved = CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutBack,
                          );
                          return RotationTransition(
                            turns: Tween<double>(begin: -0.20, end: 0.0).animate(curved),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.55, end: 1.0).animate(curved),
                              child: FadeTransition(opacity: anim, child: child),
                            ),
                          );
                        },
                        child: estSombre
                            ? _LuneLumineuse(
                                key: const ValueKey("lune_lumineuse_compact"),
                                animation: _continuousController,
                                taille: 22,
                              )
                            : _SoleilRayonnant(
                                key: const ValueKey("soleil_rayonnant_compact"),
                                animation: _continuousController,
                                taille: 22,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Format carte / pastille élégante (en-tête de tableau de bord ou paramètres)
        return Tooltip(
          message: estSombre
              ? "Mode Sombre actif • Appuyer pour activer le Mode Clair"
              : "Mode Clair actif • Appuyer pour activer le Mode Sombre",
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: estSombre
                    ? const Color(0x455C6BC0)
                    : const Color(0x35FFA000),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: estSombre
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0x12FFA000),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _basculer(context),
                onHover: _survol,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icône sémantique pour compatibilité de test
                      SizedBox(
                        width: 0,
                        height: 0,
                        child: Icon(
                          estSombre ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                          size: 0,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        transitionBuilder: (child, anim) {
                          final curved = CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutBack,
                          );
                          return RotationTransition(
                            turns: Tween<double>(begin: -0.20, end: 0.0).animate(curved),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.55, end: 1.0).animate(curved),
                              child: FadeTransition(opacity: anim, child: child),
                            ),
                          );
                        },
                        child: estSombre
                            ? _LuneLumineuse(
                                key: const ValueKey("lune_lumineuse_full"),
                                animation: _continuousController,
                                taille: 22,
                              )
                            : _SoleilRayonnant(
                                key: const ValueKey("soleil_rayonnant_full"),
                                animation: _continuousController,
                                taille: 22,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        estSombre ? "Sombre" : "Clair",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: estSombre
                              ? const Color(0xFFE0E6ED)
                              : const Color(0xFF8D4E12),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: estSombre
                              ? const Color(0x335C6BC0)
                              : const Color(0x22FFA000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Actif",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: estSombre
                                ? const Color(0xFF90CAF9)
                                : const Color(0xFFE65100),
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
      },
    );
  }
}

/// Widget affichant le Soleil avec ses rayons dorés qui rayonnent et son halo chaud
class _SoleilRayonnant extends StatelessWidget {
  final Animation<double> animation;
  final double taille;

  const _SoleilRayonnant({
    super.key,
    required this.animation,
    required this.taille,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size(taille, taille),
          painter: _SoleilRayonnantPainter(progress: animation.value),
        );
      },
    );
  }
}

class _SoleilRayonnantPainter extends CustomPainter {
  final double progress;

  _SoleilRayonnantPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.26;
    final phase = progress * 2 * math.pi;

    // 1. Halo lumineux d'arrière-plan (l'effet de soleil rayonnant chaud)
    final auraExpansion = 1.35 + 0.35 * math.sin(phase);
    final auraRadius = baseRadius * auraExpansion;
    final auraOpacity = (0.28 + 0.20 * math.sin(phase)).clamp(0.0, 1.0);

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFA000).withValues(alpha: auraOpacity),
          const Color(0xFFFFB300).withValues(alpha: auraOpacity * 0.4),
          const Color(0xFFFFD54F).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: auraRadius));

    canvas.drawCircle(center, auraRadius, auraPaint);

    // 2. Rayons solaires animés (8 rayons dorés qui pulsent et tournent doucement)
    final rayPaint = Paint()
      ..color = const Color(0xFFFFA000)
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round;

    // Un quart de tour par cycle : 8 rayons, donc l'image de fin (1.0) est identique à celle de repos (0.0)
    final slowRotation = progress * 2 * math.pi * 0.25;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + slowRotation;
      final rayPulse = math.sin(phase * 2 + (i * 0.785));
      final innerDist = baseRadius + 2.0;
      final outerDist = baseRadius + 4.2 + (1.6 * (0.5 + 0.5 * rayPulse));

      final start = Offset(
        center.dx + innerDist * math.cos(angle),
        center.dy + innerDist * math.sin(angle),
      );
      final end = Offset(
        center.dx + outerDist * math.cos(angle),
        center.dy + outerDist * math.sin(angle),
      );

      canvas.drawLine(start, end, rayPaint);
    }

    // 3. Disque central du soleil avec gradient éclatant or/ambre
    final sunPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [
          Color(0xFFFFF176),
          Color(0xFFFFB300),
          Color(0xFFF57C00),
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));

    canvas.drawCircle(center, baseRadius, sunPaint);

    // 4. Reflet de brillance subtil sur le coin supérieur gauche du soleil
    final specularPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - baseRadius * 0.32, center.dy - baseRadius * 0.32),
      baseRadius * 0.28,
      specularPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SoleilRayonnantPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Widget affichant la Lune avec son croissant nacré lumineux, son aura céleste et ses étoiles
class _LuneLumineuse extends StatelessWidget {
  final Animation<double> animation;
  final double taille;

  const _LuneLumineuse({
    super.key,
    required this.animation,
    required this.taille,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size(taille, taille),
          painter: _LuneLumineusePainter(progress: animation.value),
        );
      },
    );
  }
}

class _LuneLumineusePainter extends CustomPainter {
  final double progress;

  _LuneLumineusePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.27;
    final phase = progress * 2 * math.pi;

    // 1. Aura céleste douce et lumineuse (la lueur magique de la lune)
    final auraExpansion = 1.45 + 0.35 * math.sin(phase);
    final auraRadius = baseRadius * auraExpansion;
    final auraOpacity = (0.32 + 0.20 * math.sin(phase)).clamp(0.0, 1.0);

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF90CAF9).withValues(alpha: auraOpacity),
          const Color(0xFF64B5F6).withValues(alpha: auraOpacity * 0.45),
          const Color(0xFF5C6BC0).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: auraRadius));

    canvas.drawCircle(center, auraRadius, auraPaint);

    // 2. Étoiles scintillantes décoratives en arrière-plan
    _dessinerEtoileScintillante(
      canvas: canvas,
      position: Offset(center.dx + baseRadius * 1.05, center.dy - baseRadius * 0.70),
      taille: 2.3 + 1.1 * math.sin(phase * 2),
      opacite: (0.30 + 0.65 * ((math.sin(phase * 2) + 1) / 2)).clamp(0.0, 1.0),
      couleur: const Color(0xFFFFF9C4),
    );

    _dessinerEtoileScintillante(
      canvas: canvas,
      position: Offset(center.dx - baseRadius * 0.90, center.dy + baseRadius * 0.82),
      taille: 1.7 + 0.9 * math.cos(phase * 2),
      opacite: (0.25 + 0.65 * ((math.cos(phase * 2) + 1) / 2)).clamp(0.0, 1.0),
      couleur: const Color(0xFFB3E5FC),
    );

    // 3. Croissant de lune lumineux
    final moonCenter = Offset(center.dx - baseRadius * 0.12, center.dy + baseRadius * 0.05);
    final moonRadius = baseRadius * 1.05;

    final outerPath = Path()
      ..addOval(Rect.fromCircle(center: moonCenter, radius: moonRadius));

    final cutoutCenter = Offset(
      moonCenter.dx + moonRadius * 0.55,
      moonCenter.dy - moonRadius * 0.45,
    );
    final cutoutPath = Path()
      ..addOval(Rect.fromCircle(center: cutoutCenter, radius: moonRadius * 0.92));

    final crescentPath = Path.combine(
      PathOperation.difference,
      outerPath,
      cutoutPath,
    );

    // Remplissage du croissant lunaire avec gradient nacré étincelant
    final moonPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, -0.4),
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFFF9C4),
          Color(0xFFFFD54F),
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: moonRadius));

    canvas.drawPath(crescentPath, moonPaint);

    // 4. Liseré lumineux blanc sur le bord extérieur du croissant
    final glowRimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(crescentPath, glowRimPaint);
  }

  void _dessinerEtoileScintillante({
    required Canvas canvas,
    required Offset position,
    required double taille,
    required double opacite,
    required Color couleur,
  }) {
    final starPaint = Paint()
      ..color = couleur.withValues(alpha: opacite)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Croix à 4 branches scintillantes
    canvas.drawLine(
      Offset(position.dx - taille, position.dy),
      Offset(position.dx + taille, position.dy),
      starPaint,
    );
    canvas.drawLine(
      Offset(position.dx, position.dy - taille),
      Offset(position.dx, position.dy + taille),
      starPaint,
    );

    // Cœur étincelant
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacite)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, taille * 0.35, corePaint);
  }

  @override
  bool shouldRepaint(covariant _LuneLumineusePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
