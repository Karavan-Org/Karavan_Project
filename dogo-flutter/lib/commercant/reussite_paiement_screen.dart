import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'mes_commandes_screen.dart';

/// Écran de confirmation de Paiement Réussi conforme au design Figma (# reussite paiement)
class ReussitePaiementScreen extends StatelessWidget {
  final String titreProduit;
  final String paysOrigine;
  final int prixUnitaire;
  final int quantite;
  final int montantTotal;
  final String moyenPaiement;
  final String dateHeure;
  final String imagePath;
  final int piecesActuelles;
  final int piecesObjectif;

  const ReussitePaiementScreen({
    super.key,
    this.titreProduit = "Sneakers Premium",
    this.paysOrigine = "Turquie",
    this.prixUnitaire = 8500,
    this.quantite = 25,
    this.montantTotal = 212500,
    this.moyenPaiement = "Orange Money",
    this.dateHeure = "12 sept. 2026 - 10:24",
    this.imagePath = "assets/images/Nike_Joyride-removebg-preview.png",
    this.piecesActuelles = 780,
    this.piecesObjectif = 1000,
  });

  String _formatMontant(int montant) {
    final str = montant.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return "${str.replaceAllMapped(reg, (Match m) => '${m[1]} ')} FCFA";
  }

  void _confirmerAnnulation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Annuler la commande ?",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          "Vos fonds seront immédiatement recrédités sur votre solde AchatGroup sans aucuns frais d'annulation.",
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Garder ma commande", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Commande annulée. Vos fonds sont de retour sur votre compte."),
                  backgroundColor: Color(0xFFE53935),
                ),
              );
              Navigator.pop(context);
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
    final double pct = (piecesActuelles / piecesObjectif).clamp(0.0, 1.0);
    final int pctInt = (pct * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // Fond crème doux du Design System
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E), size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. GRAND BADGE CIRCULAIRE VERT AVEC CONFETTIS / PARTICULES FIGMA
            SizedBox(
              height: 94,
              width: 94,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Particules multicolores stylisées autour du badge
                  CustomPaint(
                    size: const Size(94, 94),
                    painter: _ConfettiPainter(),
                  ),
                  // Cercle vert succès
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1EB980), // Vert succès vibrant
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x331EB980),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. TITRE & SOUS-TITRE PRINCIPAL
            const Text(
              "Paiement effectué\navec succès !",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
                height: 1.25,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Votre participation au groupe a bien été prise en compte.\nLes fonds sont sécurisés sur votre compte AchatGroup jusqu'à la validation du groupe.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B6B6B),
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. ENCART DE SÉCURITÉ ("Votre paiement est sécurisé")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFE7CD), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1EB980),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Votre paiement est sécurisé",
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF136838),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Nous ne transférons les fonds au courtier que lorsque le groupe atteint 100%.",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF267345),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. MINI-CARTE PRODUIT FIGMA (Sneakers Premium / Nike Joyride)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEFE8DD), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A46321E),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Vignette du produit sur fond beige clair
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 82,
                      height: 82,
                      color: const Color(0xFFF6F0E6),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          size: 38,
                          color: Color(0xFF9E6E4B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Informations produit & Jauge d'avancement
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                titreProduit,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF1E1E1E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF2DC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Groupe en cours",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD98200),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          paysOrigine,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_formatMontant(prixUnitaire)} / unité",
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Barre de progression orange/dorée
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFF0EBE1),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEEA823)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "$piecesActuelles / $piecesObjectif pièces",
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF888888),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "$pctInt%",
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFEEA823),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // 5. SECTION DÉTAILS DE VOTRE PAIEMENT
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Détails de votre paiement",
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildDetailRow(
              icon: Icons.inventory_2_outlined,
              label: "Quantité commandée",
              value: "$quantite pièces",
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.sell_outlined,
              label: "Prix unitaire",
              value: _formatMontant(prixUnitaire),
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.receipt_long_outlined,
              label: "Montant total",
              value: _formatMontant(montantTotal),
              isBoldValue: true,
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.smartphone_outlined,
              label: "Moyen de paiement",
              value: moyenPaiement,
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.access_time_outlined,
              label: "Date et heure",
              value: dateHeure,
            ),

            const SizedBox(height: 32),

            // 6. BOUTON D'ACTION PRINCIPAL : "Voir mes commandes →"
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const MesCommandesScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9E6E4B), // Brun/Camel officiel Figma
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Voir mes commandes",
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 7. LIEN ROUGE : "Annuler Commande"
            TextButton(
              onPressed: () => _confirmerAnnulation(context),
              child: const Text(
                "Annuler Commande",
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isBoldValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9E6E4B)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A7A7A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isBoldValue ? FontWeight.w900 : FontWeight.w700,
              color: const Color(0xFF1E1E1E),
            ),
          ),
        ],
      ),
    );
  }
}

/// Peintre personnalisé des confettis/particules autour du rond de succès
class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final particles = [
      _Dot(cx - 36, cy - 22, 2.5, const Color(0xFF1EB980)),
      _Dot(cx + 38, cy - 18, 3.0, const Color(0xFFEEA823)),
      _Dot(cx + 26, cy - 36, 2.2, const Color(0xFF9E6E4B)),
      _Dot(cx - 24, cy - 38, 2.0, const Color(0xFF1EB980)),
      _Dot(cx - 40, cy + 18, 2.8, const Color(0xFFEEA823)),
      _Dot(cx + 36, cy + 24, 2.4, const Color(0xFF1EB980)),
    ];

    for (final p in particles) {
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dot {
  final double x;
  final double y;
  final double radius;
  final Color color;
  _Dot(this.x, this.y, this.radius, this.color);
}
