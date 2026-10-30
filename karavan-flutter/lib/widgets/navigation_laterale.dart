import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'karavan_logo.dart';

/// Rail de navigation des grands écrans, pendant vertical de la barre du bas : les quatre onglets
/// de part et d'autre d'un emplacement libre où se pose le bouton central (+), au milieu du rail.
class RailNavigation extends StatelessWidget {
  static const double largeur = 96;

  /// Hauteur réservée au bouton central entre les deux paires d'onglets.
  static const double espaceBoutonCentral = 88;

  final List<Widget> onglets;

  const RailNavigation({super.key, required this.onglets});

  @override
  Widget build(BuildContext context) {
    final moitie = onglets.length ~/ 2;
    Widget onglet(Widget o) => SizedBox(height: 68, width: largeur, child: o);
    return Container(
      width: largeur,
      decoration: BoxDecoration(
        color: AppTheme.couleurBandeauNavigation(context),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.estSombre(context)
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0x332C241E),
            blurRadius: 14,
            offset: const Offset(3, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Stack(
          children: [
            const Positioned(top: 20, left: 0, right: 0, child: Center(child: KaravanLogo(taille: 44))),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in onglets.take(moitie)) onglet(o),
                  const SizedBox(height: espaceBoutonCentral),
                  for (final o in onglets.skip(moitie)) onglet(o),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Géométrie du menu en arc du bouton central : éventail vers le haut au-dessus de la barre
/// du bas, ou vers la droite depuis le bouton du [RailNavigation].
class GeometrieArc {
  final bool laterale;

  /// Rayon de l'arc au-dessus de la barre du bas (propre à chaque espace).
  final double rayonBarre;

  const GeometrieArc({required this.laterale, this.rayonBarre = 124});

  double get rayon => laterale ? 150 : rayonBarre;

  /// Angle (en degrés, sens trigonométrique) du bouton [index] sur les quatre de l'arc.
  double angle(int index) =>
      (laterale ? const [60.0, 20.0, -20.0, -60.0] : const [152.0, 112.0, 68.0, 28.0])[index];

  /// Début de la trace lumineuse en angles du Canvas (0 = Est, -π/2 = Nord), balayée sur 0,8π.
  double get debutTrace => laterale ? -math.pi * 0.40 : -math.pi * 0.90;

  Size get tailleTrace => laterale ? const Size(180, 300) : const Size(300, 180);

  /// Centre de la trace dans sa zone : le bouton central (centré à 38 px du bord, demi-largeur d'un bouton).
  Offset centreTrace(Size taille) =>
      laterale ? Offset(38, taille.height / 2) : Offset(taille.width / 2, taille.height);

  Alignment get ancrage => laterale ? Alignment.centerLeft : Alignment.bottomCenter;

  /// Place la zone de l'arc sur le bouton central, dans la pile du corps de l'espace.
  Widget positionner(List<Widget> elements) {
    final zone = SizedBox(
      width: laterale ? 260 : 340,
      height: laterale ? 380 : 220,
      child: Stack(clipBehavior: Clip.none, alignment: ancrage, children: elements),
    );
    if (laterale) {
      return Positioned(
        left: RailNavigation.largeur / 2 - 38,
        top: 0,
        bottom: 0,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: zone),
        ),
      );
    }
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomCenter, child: zone),
      ),
    );
  }
}
