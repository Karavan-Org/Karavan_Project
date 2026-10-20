import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Emblème officiel Karavan.
///
/// Un « K » formé de trois routes : le fût doré est le corridor d'acheminement,
/// les deux bras (camel et vert) sont les flux de commerçants et de grossistes
/// qui convergent vers un nœud commun — le groupe d'achat qui consolide la
/// commande avant le départ de la caravane.
class KaravanLogo extends StatelessWidget {
  final double taille;

  const KaravanLogo({super.key, this.taille = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: taille,
      child: const CustomPaint(painter: KaravanEmblemePainter()),
    );
  }
}

/// Dessin vectoriel de l'emblème, piloté par des progressions 0 → 1 pour l'animation.
/// Les valeurs par défaut donnent l'emblème complet et statique.
class KaravanEmblemePainter extends CustomPainter {
  /// Tracé du fût (de bas en haut).
  final double fut;

  /// Tracé du bras supérieur (de la pointe vers le nœud).
  final double brasHaut;

  /// Tracé du bras inférieur (de la pointe vers le nœud).
  final double brasBas;

  /// Apparition du nœud de convergence.
  final double noeud;

  /// Intensité du halo lumineux autour des tracés (0 = aucun).
  final double halo;

  const KaravanEmblemePainter({
    this.fut = 1,
    this.brasHaut = 1,
    this.brasBas = 1,
    this.noeud = 1,
    this.halo = 0,
  });

  static const Color or = Color(0xFFF0B429);
  static const Color orProfond = Color(0xFFD98E04);
  static const Color camel = Color(0xFFD4A27A);
  static const Color camelProfond = Color(0xFFAC7F5E);
  static const Color vert = Color(0xFF3DD68C);
  static const Color vertProfond = Color(0xFF16A06A);
  static const Color ivoire = Color(0xFFFAF8F5);

  // Géométrie dans une boîte de 100 × 100.
  static const Offset futBas = Offset(25, 87);
  static const Offset futHaut = Offset(25, 13);
  static const Offset centreNoeud = Offset(45, 50);
  static const Offset pointeHaut = Offset(80, 13);
  static const Offset pointeBas = Offset(82, 87);
  static const double epaisseurFut = 16;
  static const double epaisseurBras = 14;
  static const double rayonNoeud = 7.5;

  static Path cheminFut() => Path()
    ..moveTo(futBas.dx, futBas.dy)
    ..lineTo(futHaut.dx, futHaut.dy);

  static Path cheminBrasHaut() => Path()
    ..moveTo(pointeHaut.dx, pointeHaut.dy)
    ..cubicTo(68, 22, 55, 37, centreNoeud.dx, centreNoeud.dy);

  static Path cheminBrasBas() => Path()
    ..moveTo(pointeBas.dx, pointeBas.dy)
    ..cubicTo(70, 78, 56, 63, centreNoeud.dx, centreNoeud.dy);

  /// Position (dans la boîte 100 × 100) de la tête d'un tracé partiel.
  static Offset tete(Path chemin, double t) {
    final metrique = chemin.computeMetrics().first;
    final tangente = metrique.getTangentForOffset(metrique.length * t.clamp(0.0, 1.0));
    return tangente?.position ?? Offset.zero;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final echelle = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * echelle) / 2, (size.height - 100 * echelle) / 2);
    canvas.scale(echelle);

    _trait(canvas, cheminBrasBas(), brasBas, epaisseurBras, vertProfond, vert);
    _trait(canvas, cheminBrasHaut(), brasHaut, epaisseurBras, camelProfond, camel);
    _trait(canvas, cheminFut(), fut, epaisseurFut, orProfond, or);
    _noeud(canvas);

    canvas.restore();
  }

  void _trait(Canvas canvas, Path chemin, double t, double epaisseur, Color debut, Color fin) {
    if (t <= 0) return;
    final metrique = chemin.computeMetrics().first;
    final partiel = metrique.extractPath(0, metrique.length * t.clamp(0.0, 1.0));
    final bornes = chemin.getBounds().inflate(epaisseur);
    final depart = metrique.getTangentForOffset(0)!.position;
    final arrivee = metrique.getTangentForOffset(metrique.length)!.position;

    if (halo > 0) {
      canvas.drawPath(
        partiel,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = epaisseur * 1.6
          ..color = fin.withValues(alpha: 0.45 * halo)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, epaisseur * 0.9),
      );
    }

    canvas.drawPath(
      partiel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = epaisseur
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(depart, arrivee, [fin, debut]),
    );

    // Reflet fin sur l'arête pour donner du volume sans effet « gadget »
    canvas.drawPath(
      partiel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = epaisseur * 0.22
        ..shader = ui.Gradient.linear(
          bornes.topLeft,
          bornes.bottomRight,
          [Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0.0)],
        ),
    );
  }

  void _noeud(Canvas canvas) {
    if (noeud <= 0) return;
    final r = rayonNoeud * Curves.easeOutBack.transform(noeud.clamp(0.0, 1.0));
    if (halo > 0) {
      canvas.drawCircle(
        centreNoeud,
        r * 1.9,
        Paint()
          ..color = ivoire.withValues(alpha: 0.35 * halo)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
      );
    }
    // Ombre de contact : garde le nœud lisible sur fond clair
    canvas.drawCircle(
      centreNoeud + const Offset(0, 0.8),
      r + 0.6,
      Paint()
        ..color = const Color(0xFF2C241E).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawCircle(
      centreNoeud,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          centreNoeud - Offset(r * 0.35, r * 0.35),
          r * 1.4,
          const [Colors.white, ivoire, Color(0xFFE9DFD3)],
          const [0.0, 0.6, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant KaravanEmblemePainter old) =>
      old.fut != fut ||
      old.brasHaut != brasHaut ||
      old.brasBas != brasBas ||
      old.noeud != noeud ||
      old.halo != halo;
}
