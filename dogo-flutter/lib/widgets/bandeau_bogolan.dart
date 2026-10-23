import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bandeau à motifs bogolan de la Palette Dɔgɔ : sur fond terre sombre, une rangée
/// de points rose et ocre alternés, puis deux lignes brisées (ocre, rose).
///
/// [progression] (0 → 1) révèle le motif de gauche à droite pour les animations.
class BandeauBogolan extends StatelessWidget {
  final double hauteur;
  final double rayon;
  final double progression;

  const BandeauBogolan({super.key, this.hauteur = 40, this.rayon = 12, this.progression = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      width: double.infinity,
      child: CustomPaint(painter: BogolanPainter(rayon: rayon, progression: progression)),
    );
  }
}

class BogolanPainter extends CustomPainter {
  final double rayon;
  final double progression;

  const BogolanPainter({this.rayon = 12, this.progression = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (progression <= 0) return;
    final h = size.height;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(rayon));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(Offset.zero & size, Paint()..color = AppTheme.terre);

    // Révélation progressive : le motif se tisse de gauche à droite
    final limite = size.width * progression;
    canvas.clipRect(Rect.fromLTWH(0, 0, limite, h));

    // Rangée de points alternés
    final pasPoints = h * 0.5;
    final yPoints = h * 0.1;
    final rayonPoint = math.max(1.2, h * 0.045);
    var i = 0;
    for (var x = pasPoints * 0.5 + rayonPoint; x < size.width; x += pasPoints, i++) {
      canvas.drawCircle(Offset(x, yPoints), rayonPoint, Paint()..color = i.isEven ? AppTheme.rose : AppTheme.ocre);
    }

    // Deux lignes brisées
    final periode = h * 0.3;
    final trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, h * 0.04)
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.butt;
    void zigzag(double haut, double bas, Color couleur) {
      final chemin = Path()..moveTo(-periode, bas);
      var monte = true;
      for (var x = -periode / 2; x <= size.width + periode; x += periode / 2) {
        chemin.lineTo(x, monte ? haut : bas);
        monte = !monte;
      }
      canvas.drawPath(chemin, trait..color = couleur);
    }

    zigzag(h * 0.28, h * 0.52, AppTheme.ocre);
    zigzag(h * 0.60, h * 0.84, AppTheme.rose.withValues(alpha: 0.85));
    canvas.restore();
  }

  @override
  bool shouldRepaint(BogolanPainter old) => old.progression != progression || old.rayon != rayon;
}
