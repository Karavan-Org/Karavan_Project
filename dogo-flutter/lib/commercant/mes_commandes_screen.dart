import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'code_retrait_commercant_screen.dart';

/// Écran "Mes commandes" conforme au modèle Figma exact
/// Présente :
/// 1. La liste des commandes actives (cartes horizontales avec visuels, détails et bouton "Annuler")
/// 2. Le stepper de suivi d'étapes (Achat effectué, Chez le transitaire, En transit, Arrivée à Bamako, Disponible au retrait)
/// 3. La carte d'illustration du trajet maritime/aérien (Chine 📍 ---> 🚢 Cargo ---> 📍 Bamako)
/// 4. La bannière flottante de statut ("Votre colis est en transit - Arrivée estimée : 12 octobre 2026")
class MesCommandesScreen extends StatefulWidget {
  const MesCommandesScreen({super.key});

  @override
  State<MesCommandesScreen> createState() => _MesCommandesScreenState();
}

class _MesCommandesScreenState extends State<MesCommandesScreen> {
  int _selectedOrderIndex = 0;

  final List<Map<String, dynamic>> _commandes = [];

  void _annulerCommande(int index) {
    final cmd = _commandes[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          "Annuler ${cmd['titre']} ?",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          "Êtes-vous sûr de vouloir annuler la ${cmd['numero']} ? Le montant intégral de 212 500 FCFA sera recrédité sur votre portefeuille.",
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Retour", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _commandes.removeAt(index);
                if (_selectedOrderIndex >= _commandes.length) {
                  _selectedOrderIndex = 0;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Commande annulée avec succès. Montant remboursé."),
                  backgroundColor: Color(0xFFE53935),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Confirmer l'annulation"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasOrders = _commandes.isNotEmpty;
    final activeCmd = hasOrders ? _commandes[_selectedOrderIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // Fond doux Design System
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E), size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          "Mes commandes",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: hasOrders
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. LISTE DES CARTES DE COMMANDES (Figma Top Cards)
                  for (int i = 0; i < _commandes.length; i++) ...[
                    _buildOrderCard(i),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 8),

                  // 2. CARTE BLANCHE DE SUIVI : LE STEPPER VERTICAL FIGMA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFEFE8DD), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A46321E),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepRow(
                          stepIndex: 0,
                          currentActiveStep: activeCmd!['etapeActive'] as int,
                          title: "Achat effectué",
                          dateOrSubtitle: "12 sept. 2026",
                          isFirst: true,
                        ),
                        _buildConnectingLine(
                          isPassed: (activeCmd['etapeActive'] as int) > 0,
                        ),
                        _buildStepRow(
                          stepIndex: 1,
                          currentActiveStep: activeCmd['etapeActive'] as int,
                          title: "Chez le transitaire",
                          dateOrSubtitle: "18 sept. 2026",
                        ),
                        _buildConnectingLine(
                          isPassed: (activeCmd['etapeActive'] as int) > 1,
                        ),
                        _buildStepRow(
                          stepIndex: 2,
                          currentActiveStep: activeCmd['etapeActive'] as int,
                          title: "En transit",
                          dateOrSubtitle: "Arrivée estimée : 12 oct. 2026",
                          isActiveStep: (activeCmd['etapeActive'] as int) == 2,
                        ),
                        _buildConnectingLine(
                          isPassed: (activeCmd['etapeActive'] as int) > 2,
                          isDashed: true,
                        ),
                        _buildStepRow(
                          stepIndex: 3,
                          currentActiveStep: activeCmd['etapeActive'] as int,
                          title: "Arrivée à Bamako",
                          dateOrSubtitle: null,
                          isPending: (activeCmd['etapeActive'] as int) < 3,
                        ),
                        _buildConnectingLine(
                          isPassed: (activeCmd['etapeActive'] as int) > 3,
                          isDashed: true,
                        ),
                        _buildStepRow(
                          stepIndex: 4,
                          currentActiveStep: activeCmd['etapeActive'] as int,
                          title: "Disponible au retrait",
                          dateOrSubtitle: null,
                          isPending: (activeCmd['etapeActive'] as int) < 4,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. ILLUSTRATION DU TRAJET MARITIME (Chine 📍 ---> 🚢 ---> 📍 Bamako)
                  Container(
                    width: double.infinity,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F2F8), // Fond bleu ciel doux Figma
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD4E6F2), width: 1.2),
                    ),
                    child: CustomPaint(
                      painter: _MaritimeRoutePainter(
                        departLabel: activeCmd['origine'] as String,
                        arriveeLabel: activeCmd['destination'] as String,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. BANNIÈRE FLOTTANTE DE STATUT : "Votre colis est en transit"
                  InkWell(
                    onTap: () {
                      if ((activeCmd['etapeActive'] as int) >= 4) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CodeRetraitCommercantScreen(
                              nomProduit: activeCmd['titre'] as String,
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9E6E4B), // Brun/Camel Figma
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2E9E6E4B),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeCmd['statut'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Arrivée estimée : ${activeCmd['arrivee']}",
                            style: const TextStyle(
                              color: Color(0xFFFFDFA6),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 46,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Aucune commande active",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Rejoignez un groupe d'achat pour passer votre première commande groupée.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Carte individuelle de commande active (Figma Top Card)
  Widget _buildOrderCard(int index) {
    final cmd = _commandes[index];
    final bool isSelected = _selectedOrderIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _selectedOrderIndex = index);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF9E6E4B) : const Color(0xFFEFE8DD),
            width: isSelected ? 1.6 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0x1A9E6E4B) : const Color(0x0846321E),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Vignette Produit sur fond beige clair
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 62,
                height: 62,
                color: const Color(0xFFF6F0E6),
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  cmd['image'] as String,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.inventory_2_outlined,
                    size: 30,
                    color: Color(0xFF9E6E4B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Détails de la commande
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cmd['titre'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cmd['details'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cmd['numero'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9E9E9E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Bouton "Annuler" en rouge
            TextButton(
              onPressed: () => _annulerCommande(index),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                "Annuler",
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ligne d'une étape de la chronologie (Stepper Figma)
  Widget _buildStepRow({
    required int stepIndex,
    required int currentActiveStep,
    required String title,
    required String? dateOrSubtitle,
    bool isActiveStep = false,
    bool isPending = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final bool isCompleted = stepIndex < currentActiveStep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icône / Pastille circulaire de l'étape
        _buildStepBadge(isCompleted, isActiveStep, isPending),
        const SizedBox(width: 14),

        // Libellé et sous-titre de l'étape
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: (isActiveStep || isCompleted) ? FontWeight.w800 : FontWeight.w600,
                  color: isActiveStep
                      ? const Color(0xFF9E6E4B)
                      : (isCompleted ? const Color(0xFF1E1E1E) : const Color(0xFF6B6B6B)),
                ),
              ),
              if (dateOrSubtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  dateOrSubtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActiveStep ? const Color(0xFF8C5F3E) : const Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Chevron droit '>' si étape validée ou active
        if (!isPending)
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: Color(0xFFB0B0B0),
          ),
      ],
    );
  }

  Widget _buildStepBadge(bool isCompleted, bool isActive, bool isPending) {
    if (isCompleted) {
      // Pastille verte avec coche blanche
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF1EB980),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 17, color: Colors.white),
      );
    } else if (isActive) {
      // Pastille marron/camel avec icône de bateau / colis
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF9E6E4B),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9E6E4B).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.directions_boat_filled, size: 16, color: Colors.white),
      );
    } else {
      // Pastille grise avec point central bleu
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF1F5),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDCE2E8), width: 1.2),
        ),
        child: Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF5B92D1),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
  }

  /// Ligne de liaison verticale entre les étapes
  Widget _buildConnectingLine({bool isPassed = false, bool isDashed = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 13),
      width: 2,
      height: 22,
      child: isDashed
          ? CustomPaint(
              painter: _DashedLinePainter(
                color: const Color(0xFFBAC4CE),
              ),
            )
          : Container(
              color: isPassed ? const Color(0xFF1EB980) : const Color(0xFFBAC4CE),
            ),
    );
  }
}

/// Peintre de ligne pointillée verticale pour les étapes futures
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 3.5), paint);
      y += 6.5;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Peintre de la carte maritime stylisée : Chine 📍 ---> 🚢 Cargo ---> 📍 Bamako
class _MaritimeRoutePainter extends CustomPainter {
  final String departLabel;
  final String arriveeLabel;

  _MaritimeRoutePainter({
    required this.departLabel,
    required this.arriveeLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Coordonnées départ (Chine) et arrivée (Bamako)
    final pDepart = Offset(w * 0.14, h * 0.58);
    final pArrivee = Offset(w * 0.86, h * 0.58);

    // Tracé de la route maritime en courbe douce
    final path = Path()
      ..moveTo(pDepart.dx, pDepart.dy)
      ..cubicTo(
        w * 0.35,
        h * 0.32,
        w * 0.65,
        h * 0.32,
        pArrivee.dx,
        pArrivee.dy,
      );

    // Dessin de la ligne pointillée bleue
    final routePaint = Paint()
      ..color = const Color(0xFF4A8AC4)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    // Approximation de pointillés le long de la courbe
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extract = metric.extractPath(distance, distance + 4.5);
        canvas.drawPath(extract, routePaint);
        distance += 8.5;
      }
    }

    // 1. Point de départ (Chine) : Pin rouge
    final redPinPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawCircle(Offset(pDepart.dx, pDepart.dy - 10), 6.5, redPinPaint);
    canvas.drawCircle(Offset(pDepart.dx, pDepart.dy - 10), 2.5, Paint()..color = Colors.white);
    final textPainterDepart = TextPainter(
      text: TextSpan(
        text: departLabel,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF333333),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterDepart.layout();
    textPainterDepart.paint(canvas, Offset(pDepart.dx - (textPainterDepart.width / 2), pDepart.dy + 3));

    // 2. Point d'arrivée (Bamako) : Pin bleu
    final bluePinPaint = Paint()..color = const Color(0xFF1E88E5);
    canvas.drawCircle(Offset(pArrivee.dx, pArrivee.dy - 10), 6.5, bluePinPaint);
    canvas.drawCircle(Offset(pArrivee.dx, pArrivee.dy - 10), 2.5, Paint()..color = Colors.white);
    final textPainterArrivee = TextPainter(
      text: TextSpan(
        text: arriveeLabel,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF333333),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterArrivee.layout();
    textPainterArrivee.paint(canvas, Offset(pArrivee.dx - (textPainterArrivee.width / 2), pArrivee.dy + 3));

    // 3. Dessin du Cargo / Navire au centre du trajet
    final shipCenter = Offset(w * 0.50, h * 0.35);

    // Coque du bateau
    final hullPath = Path()
      ..moveTo(shipCenter.dx - 14, shipCenter.dy + 3)
      ..lineTo(shipCenter.dx + 14, shipCenter.dy + 3)
      ..lineTo(shipCenter.dx + 10, shipCenter.dy + 9)
      ..lineTo(shipCenter.dx - 11, shipCenter.dy + 9)
      ..close();
    canvas.drawPath(hullPath, Paint()..color = const Color(0xFF1E3A5F));

    // Conteneurs colorés sur le pont
    canvas.drawRect(
      Rect.fromLTWH(shipCenter.dx - 9, shipCenter.dy - 4, 6, 6),
      Paint()..color = const Color(0xFFEEA823),
    );
    canvas.drawRect(
      Rect.fromLTWH(shipCenter.dx - 2, shipCenter.dy - 4, 6, 6),
      Paint()..color = const Color(0xFF1EB980),
    );
    canvas.drawRect(
      Rect.fromLTWH(shipCenter.dx + 5, shipCenter.dy - 2, 5, 4),
      Paint()..color = const Color(0xFFE53935),
    );

    // Cabine blanche
    canvas.drawRect(
      Rect.fromLTWH(shipCenter.dx - 12, shipCenter.dy - 3, 3, 5),
      Paint()..color = Colors.white,
    );

    // Ondulations de vagues sous le bateau
    final wavePaint = Paint()
      ..color = const Color(0xFF7CB6E6).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(shipCenter.dx - 18, shipCenter.dy + 12),
      Offset(shipCenter.dx + 18, shipCenter.dy + 12),
      wavePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
