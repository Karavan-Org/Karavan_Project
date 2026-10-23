import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EpingleDepot extends StatelessWidget {
  final bool arrivee;
  final String nom;

  const EpingleDepot({super.key, required this.arrivee, required this.nom});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedScale(
        scale: arrivee ? 1.12 : 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x332C241E),
                      blurRadius: 6,
                      offset: Offset(0, 2))
                ],
              ),
              child: Text(nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark)),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x402C241E),
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ],
              ),
              child: const Icon(Icons.warehouse_rounded,
                  color: Colors.white, size: 20),
            ),
            CustomPaint(size: const Size(14, 10), painter: _PointeEpingle()),
          ],
        ),
      ),
    );
  }
}

class _PointeEpingle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Point bleu « vous êtes ici » avec halo pulsé et étiquette « Départ ».
class PointDepart extends StatelessWidget {
  final Animation<double> pulsation;
  final String? libelle;

  const PointDepart({super.key, required this.pulsation, this.libelle});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: pulsation,
          builder: (_, __) {
            final t = pulsation.value;
            return Container(
              width: 16 + 34 * t,
              height: 16 + 34 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bissap.withValues(alpha: 0.32 * (1 - t)),
              ),
            );
          },
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.bissap,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 4)
            ],
          ),
        ),
        if (libelle != null)
          Positioned(
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppTheme.bissap,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(libelle!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

/// Flèche de navigation GPS orientée en direct selon la direction de marche et la boussole.
class FlecheGps extends StatelessWidget {
  final double cap;
  final double rotationCarte;

  const FlecheGps({super.key, required this.cap, this.rotationCarte = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.bissap.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Transform.rotate(
        angle: (cap + rotationCarte) * math.pi / 180,
        child: const Icon(Icons.navigation_rounded,
            color: AppTheme.bissap, size: 34),
      ),
    );
  }
}

class IconePulsee extends StatelessWidget {
  final Animation<double> pulsation;
  final IconData icone;
  final double taille;

  const IconePulsee(
      {super.key,
      required this.pulsation,
      required this.icone,
      this.taille = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille * 1.4,
      height: taille * 1.4,
      child: AnimatedBuilder(
        animation: pulsation,
        builder: (_, __) {
          final t = pulsation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: taille * (0.8 + 0.6 * t),
                height: taille * (0.8 + 0.6 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.bissap.withValues(alpha: 0.22 * (1 - t)),
                ),
              ),
              Container(
                width: taille * 0.8,
                height: taille * 0.8,
                decoration: const BoxDecoration(
                    color: AppTheme.roseClair, shape: BoxShape.circle),
                child: Icon(icone, color: AppTheme.bissap, size: taille * 0.42),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// « Départ → Dépôt », comme le récapitulatif d'un trajet Google Maps.
class LigneTrajet extends StatelessWidget {
  final String depart;
  final String arrivee;

  const LigneTrajet({super.key, required this.depart, required this.arrivee});

  @override
  Widget build(BuildContext context) {
    Widget ligne(IconData icone, Color couleur, String texte) => Row(
          children: [
            Icon(icone, size: 14, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texte,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTheme.terreDouce)),
            ),
          ],
        );
    return Column(
      children: [
        ligne(Icons.radio_button_checked_rounded, AppTheme.bissap, depart),
        const SizedBox(height: 4),
        ligne(Icons.location_on_rounded, AppTheme.primary, arrivee),
      ],
    );
  }
}

class BoutonRond extends StatelessWidget {
  final IconData icone;
  final String aide;
  final VoidCallback onTap;
  final bool actif;

  const BoutonRond(
      {super.key,
      required this.icone,
      required this.aide,
      required this.onTap,
      this.actif = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: aide,
      child: Material(
        color: actif ? AppTheme.bissap : Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x402C241E),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icone, color: actif ? Colors.white : AppTheme.bissap),
          ),
        ),
      ),
    );
  }
}

/// Bouton boussole rotatif interactif (aiguille rouge pointant vers le Nord physique).
class BoutonBoussole extends StatelessWidget {
  final double rotation;
  final bool modeSuiviOrientation;
  final VoidCallback onTap;

  const BoutonBoussole({
    super.key,
    required this.rotation,
    required this.modeSuiviOrientation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: modeSuiviOrientation
          ? "Orientation : Direction de marche (cliquez pour fixer au Nord)"
          : "Orientation : Nord en haut (cliquez pour suivre la direction)",
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x402C241E),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: rotation * math.pi / 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Aiguille Nord (rouge) avec lettre N
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "N",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.danger,
                                ),
                              ),
                              CustomPaint(
                                size: const Size(8, 11),
                                painter: _AiguilleNordPainter(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Aiguille Sud (grise)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: CustomPaint(
                            size: const Size(8, 11),
                            painter: _AiguilleSudPainter(),
                          ),
                        ),
                      ),
                      // Pivot central
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppTheme.terre,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                if (modeSuiviOrientation)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.bissap,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiguilleNordPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.danger);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AiguilleSudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.textMuted);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChoixMode extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  const ChoixMode(
      {super.key,
      required this.icone,
      required this.libelle,
      required this.actif,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: actif ? AppTheme.roseClair : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: actif ? AppTheme.bissap : AppTheme.bordureForte),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone,
                size: 16, color: actif ? AppTheme.bissap : AppTheme.terreDouce),
            const SizedBox(width: 6),
            Text(libelle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: actif ? AppTheme.bissap : AppTheme.terreDouce,
                )),
          ],
        ),
      ),
    );
  }
}

/// Épingle d'un lieu trouvé lors d'une recherche OpenStreetMap.
class EpingleLieuRecherche extends StatelessWidget {
  final String nom;

  const EpingleLieuRecherche({super.key, required this.nom});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: AppTheme.terre,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
            ),
            child: Text(
              nom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.danger,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 8,
                    offset: Offset(0, 3))
              ],
            ),
            child:
                const Icon(Icons.place_rounded, color: Colors.white, size: 20),
          ),
          CustomPaint(size: const Size(12, 8), painter: _PointeEpingle()),
        ],
      ),
    );
  }
}

/// Feuille modale de recherche de lieux avec suggestions OpenStreetMap Nominatim.
