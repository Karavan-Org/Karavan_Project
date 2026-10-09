import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'onboarding_screen.dart';

/// Animation officielle de lancement de l'application DoGo
class SplashLaunchScreen extends StatefulWidget {
  const SplashLaunchScreen({super.key});

  @override
  State<SplashLaunchScreen> createState() => _SplashLaunchScreenState();
}

class _SplashLaunchScreenState extends State<SplashLaunchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasNavigated = false;
  ui.Image? _logoImage;

  @override
  void initState() {
    super.initState();
    _loadLogo();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _naviguerVersAccueil();
      }
    });
  }

  Future<void> _loadLogo() async {
    try {
      final ByteData data = await rootBundle.load('assets/logo/logoV.png');
      final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo fi = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _logoImage = fi.image;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _naviguerVersAccueil() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0D0B),
      body: Stack(
        children: [
          // 1. Halo d'ambiance cosmique / aquatique centré
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    Color(0xFF281E15),
                    Color(0xFF15110E),
                    Color(0xFF0F0D0B),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 2. Rendu complet des spirales d'eau cisaillée + logo logoV.png + DoGo (100% Canvas natif)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ShearedFluidSpiralsPainter(
                    progress: _controller.value,
                    logoImage: _logoImage,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Peintre de l'animation des spirales fluides cisaillées, logo DoGo et révélation du nom
class _ShearedFluidSpiralsPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0
  final ui.Image? logoImage;

  _ShearedFluidSpiralsPainter({
    required this.progress,
    this.logoImage,
  });

  // Couleurs officielles du Design System
  static const Color cGold = Color(0xFFEEA823);       // Jaune or vibrant
  static const Color cCamel = Color(0xFFAC7F5E);      // Camel de base
  static const Color cGreen = Color(0xFF34C759);      // Vert succès Design System
  static const Color cForest = Color(0xFF183630);     // Vert profond Design System
  static const Color cIvory = Color(0xFFFAF8F5);      // Blanc ivoire pur

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final double phaseSpiral = (progress / 0.50).clamp(0.0, 1.0);
    final double phaseBox = ((progress - 0.44) / 0.22).clamp(0.0, 1.0);
    final double phaseReveal = ((progress - 0.62) / 0.24).clamp(0.0, 1.0);
    final double phaseFinal = ((progress - 0.84) / 0.16).clamp(0.0, 1.0);

    // 1. DESSIN DES SPIRALES D'EAU CISAILLÉE (Visibles au début jusqu'à la formation du logo)
    if (progress < 0.60) {
      _drawShearedWaterSpirals(canvas, cx, cy, phaseSpiral, phaseBox);
    }

    // 2. LOGO DOGO OFFICIEL (Formé par la fusion des spirales à la place de la boîte)
    if (phaseBox > 0.0) {
      _drawLogo(canvas, cx, cy, phaseBox, phaseReveal, phaseFinal);
    }

    // 3. RÉVÉLATION DU NOM DE L'APPLICATION « DoGo »
    if (phaseReveal > 0.0) {
      _drawRevealedBrandName(canvas, cx, cy, phaseReveal, phaseFinal);
    }
  }

  /// Dessine les spirales de fluide aquatique cisaillé avec vagues, crêtes et gouttelettes
  void _drawShearedWaterSpirals(
    Canvas canvas,
    double cx,
    double cy,
    double phaseSpiral,
    double phaseBox,
  ) {
    // Opacité générale qui s'estompe quand le logo se forme
    final fadeOut = (1.0 - phaseBox * 1.4).clamp(0.0, 1.0);
    if (fadeOut <= 0.01) return;

    // Définition des 5 bras de fluide avec les couleurs du Design System
    const List<_SpiralStream> streams = [
      _SpiralStream(
        color: cGold,
        accentColor: Color(0xFFFFD56B),
        baseAngle: 0.0,
        curlDirection: 1.0,
        shearFrequency: 7.0,
        waveAmplitude: 14.0,
      ),
      _SpiralStream(
        color: cGreen,
        accentColor: Color(0xFF67E885),
        baseAngle: (2 * math.pi / 5) * 1,
        curlDirection: 1.0,
        shearFrequency: 8.5,
        waveAmplitude: 16.0,
      ),
      _SpiralStream(
        color: cCamel,
        accentColor: Color(0xFFD8AA84),
        baseAngle: (2 * math.pi / 5) * 2,
        curlDirection: 1.0,
        shearFrequency: 6.5,
        waveAmplitude: 12.0,
      ),
      _SpiralStream(
        color: cForest,
        accentColor: Color(0xFF275C51),
        baseAngle: (2 * math.pi / 5) * 3,
        curlDirection: 1.0,
        shearFrequency: 9.0,
        waveAmplitude: 15.0,
      ),
      _SpiralStream(
        color: cIvory,
        accentColor: Colors.white,
        baseAngle: (2 * math.pi / 5) * 4,
        curlDirection: 1.0,
        shearFrequency: 8.0,
        waveAmplitude: 10.0,
      ),
    ];

    // Temps fluide pour l'effet de cisaillement vivant
    final double flowTime = phaseSpiral * 8.5;
    final double vortexSpeed = 1.0 + phaseSpiral * 2.2;

    for (final stream in streams) {
      _drawSingleShearedStream(
        canvas,
        cx,
        cy,
        stream,
        flowTime,
        vortexSpeed,
        phaseSpiral,
        phaseBox,
        fadeOut,
      );
    }

    // Éclaboussures et gouttelettes orbitales
    _drawFluidDroplets(canvas, cx, cy, flowTime, phaseSpiral, fadeOut);
  }

  /// Dessine un bras de fluide individuel avec vagues de cisaillement transversales
  void _drawSingleShearedStream(
    Canvas canvas,
    double cx,
    double cy,
    _SpiralStream stream,
    double flowTime,
    double vortexSpeed,
    double phaseSpiral,
    double phaseBox,
    double opacity,
  ) {
    final double maxRadius = 240.0 * (1.0 - phaseBox * 0.85);
    final double minRadius = 14.0 * (1.0 - phaseBox);

    // Trajectoire en spirale logarithmique cisaillée
    const int sampleCount = 45;
    final List<Offset> centerPoints = [];
    final List<double> widths = [];

    for (int i = 0; i <= sampleCount; i++) {
      final double s = i / sampleCount; // 0 (extérieur) -> 1 (centre)

      // Rayon contractant vers le centre
      final double r = minRadius + (maxRadius - minRadius) * math.pow(1.0 - s, 1.35);

      // Angle en spirale avec accélération vers le centre (vortex)
      final double spiralAngle = stream.baseAngle +
          (vortexSpeed * 2.2 * math.pi * s) +
          (flowTime * 0.4);

      // Effet d'eau cisaillée (onde hydrodynamique transversale le long du ruban)
      final double wavePhase = s * stream.shearFrequency - flowTime * 2.2;
      final double shearDisplacement = math.sin(wavePhase) * stream.waveAmplitude * math.sin(s * math.pi);

      // Formule de la crête d'eau cisaillée (effilement vers le bord extérieur, gonflement au centre)
      final double px = cx + (r + shearDisplacement) * math.cos(spiralAngle);
      final double py = cy + (r + shearDisplacement) * math.sin(spiralAngle);

      centerPoints.add(Offset(px, py));

      // Épaisseur du ruban d'eau (forme en gouttelette allongée / jet d'eau effilé)
      final double ribbonWidth = math.sin(s * math.pi) * (18.0 * (1.0 - phaseBox * 0.5));
      widths.add(ribbonWidth);
    }

    if (centerPoints.length < 3) return;

    // Construction du maillage de surface du ruban fluide (bords gauche et droite)
    final Path ribbonPath = Path();
    final List<Offset> leftPoints = [];
    final List<Offset> rightPoints = [];

    for (int i = 0; i < centerPoints.length; i++) {
      final p = centerPoints[i];
      final w = widths[i];

      // Vecteur tangent pour déterminer la normale
      Offset tangent;
      if (i == 0) {
        tangent = centerPoints[1] - p;
      } else if (i == centerPoints.length - 1) {
        tangent = p - centerPoints[i - 1];
      } else {
        tangent = centerPoints[i + 1] - centerPoints[i - 1];
      }

      final double len = tangent.distance;
      final normal = (len > 0.001)
          ? Offset(-tangent.dy / len, tangent.dx / len)
          : const Offset(0, 1);

      leftPoints.add(p + normal * (w / 2));
      rightPoints.add(p - normal * (w / 2));
    }

    ribbonPath.moveTo(leftPoints.first.dx, leftPoints.first.dy);
    for (int i = 1; i < leftPoints.length; i++) {
      ribbonPath.lineTo(leftPoints[i].dx, leftPoints[i].dy);
    }
    for (int i = rightPoints.length - 1; i >= 0; i--) {
      ribbonPath.lineTo(rightPoints[i].dx, rightPoints[i].dy);
    }
    ribbonPath.close();

    // Rendu avec dégradé liquide chatoyant
    final gradient = LinearGradient(
      colors: [
        stream.accentColor.withValues(alpha: 0.1 * opacity),
        stream.color.withValues(alpha: 0.85 * opacity),
        stream.accentColor.withValues(alpha: 0.95 * opacity),
        stream.color.withValues(alpha: 0.3 * opacity),
      ],
      stops: const [0.0, 0.4, 0.75, 1.0],
    );

    final ribbonPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxRadius))
      ..style = PaintingStyle.fill;

    // Halo lumineux fluide autour du ruban
    final glowPaint = Paint()
      ..color = stream.color.withValues(alpha: 0.25 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(ribbonPath, glowPaint);
    canvas.drawPath(ribbonPath, ribbonPaint);
  }

  /// Dessine les gouttelettes et éclaboussures en orbite hydrodynamique
  void _drawFluidDroplets(
    Canvas canvas,
    double cx,
    double cy,
    double flowTime,
    double phaseSpiral,
    double opacity,
  ) {
    const int count = 24;
    for (int i = 0; i < count; i++) {
      final double seed = i * 1.61803398875;
      final double radiusFactor = ((seed * 17.0) % 1.0);
      final double r = 35.0 + radiusFactor * 140.0 * (1.0 - phaseSpiral * 0.4);
      final double speed = 1.2 + ((seed * 23.0) % 1.5);
      final double angle = seed * math.pi * 2 + flowTime * speed;

      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);

      final Color dropColor = (i % 4 == 0)
          ? cGold
          : (i % 4 == 1)
              ? cGreen
              : (i % 4 == 2)
                  ? cCamel
                  : cIvory;

      final double dropSize = 2.0 + (i % 3) * 1.5;

      final dropPaint = Paint()
        ..color = dropColor.withValues(alpha: (0.75 - radiusFactor * 0.35) * opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), dropSize, dropPaint);
    }
  }

  /// Dessine le logo DoGo officiel formé par la fusion des spirales (à la place de la boîte)
  void _drawLogo(
    Canvas canvas,
    double cx,
    double cy,
    double phaseBox,
    double phaseReveal,
    double phaseFinal,
  ) {
    // Interpolation de la formation du logo (apparition avec rebond amorti identique à la boîte)
    final double boxBirth = Curves.easeOutBack.transform(phaseBox);

    // Déplacement vers la gauche pour laisser paraître le nom DoGo (identique à la boîte)
    final double slideProgress = Curves.easeInOutCubic.transform(phaseReveal);
    final double boxX = cx - (slideProgress * 88.0);
    final double boxY = cy;

    // Légère respiration / settling physique
    final double settleRotate = (phaseFinal > 0.0) ? math.sin(phaseFinal * math.pi) * 0.03 : 0.0;
    final double boxScale = (0.2 + boxBirth * 0.8) * (1.0 + settleRotate);

    canvas.save();
    canvas.translate(boxX, boxY);
    canvas.scale(boxScale);

    // 1. Ombre diffuse projetée au sol
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45 * phaseBox)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 48), width: 100, height: 32),
      shadowPaint,
    );

    // 2. Flash lumineux d'impact lors de la fusion cristalline des spirales
    if (phaseBox < 0.65) {
      final flashAlpha = (1.0 - ((phaseBox - 0.2) / 0.45)).clamp(0.0, 1.0);
      final flashPaint = Paint()
        ..color = cGold.withValues(alpha: flashAlpha * 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
      canvas.drawCircle(Offset.zero, 60, flashPaint);
    }

    // 3. Dessin du logo DoGo officiel (assets/logo/logoV.png)
    if (logoImage != null) {
      final double imgW = logoImage!.width.toDouble();
      final double imgH = logoImage!.height.toDouble();
      const double targetW = 96.0;
      final double targetH = targetW * (imgH / imgW);
      final srcRect = Rect.fromLTWH(0, 0, imgW, imgH);
      final dstRect = Rect.fromCenter(center: Offset.zero, width: targetW, height: targetH);
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;
      canvas.drawImageRect(logoImage!, srcRect, dstRect, paint);
    }

    canvas.restore();
  }

  /// Révèle le nom de l'application « DoGo » avec une onde lumineuse élégante
  void _drawRevealedBrandName(
    Canvas canvas,
    double cx,
    double cy,
    double phaseReveal,
    double phaseFinal,
  ) {
    // Position du texte à droite du logo
    final logoX = cx + 20.0;
    final logoY = cy - 28.0;

    // Déroulement progressif de gauche à droite
    final revealWidth = 220.0 * Curves.easeOutCubic.transform(phaseReveal);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(logoX - 6, logoY - 20, revealWidth, 85));

    // Dessin du texte « DoGo » avec la typographie officielle
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: "Do",
            style: TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.2,
            ),
          ),
          TextSpan(
            text: "Go",
            style: TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.w900,
              color: cGold,
              letterSpacing: -1.2,
              shadows: [
                Shadow(
                  color: cGold.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(logoX, logoY));

    // Sous-titre de marque : "ACHAT GROUPÉ B2B"
    if (phaseReveal > 0.35) {
      final subAlpha = ((phaseReveal - 0.35) / 0.45).clamp(0.0, 1.0);
      final subPainter = TextPainter(
        text: TextSpan(
          text: "ACHAT GROUPÉ B2B",
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFD4C5B9).withValues(alpha: subAlpha * 0.9),
            letterSpacing: 2.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      subPainter.layout();
      subPainter.paint(canvas, Offset(logoX + 2, logoY + 54));
    }

    // Balayage lumineux éclatant une fois stabilisé
    if (phaseFinal > 0.0) {
      final shineX = logoX + (phaseFinal * 220);
      final shinePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(shineX - 25, logoY, 50, 65));
      canvas.drawRect(Rect.fromLTWH(logoX, logoY, 180, 65), shinePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShearedFluidSpiralsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.logoImage != logoImage;
  }
}

/// Caractéristiques d'un flux de couleur fluide
class _SpiralStream {
  final Color color;
  final Color accentColor;
  final double baseAngle;
  final double curlDirection;
  final double shearFrequency;
  final double waveAmplitude;

  const _SpiralStream({
    required this.color,
    required this.accentColor,
    required this.baseAngle,
    required this.curlDirection,
    required this.shearFrequency,
    required this.waveAmplitude,
  });
}
