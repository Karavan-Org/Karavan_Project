import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran du Code de Retrait sécurisé pour le Commerçant
/// Affiche le QR Code dynamique et le code PIN à 4 chiffres à présenter au courtier/magasinier.
class CodeRetraitCommercantScreen extends StatelessWidget {
  final String codeCommande;
  final String? codePin;
  final String nomProduit;
  final int quantite;
  final String pointRetrait;
  final String courtierNom;

  const CodeRetraitCommercantScreen({
    super.key,
    this.codeCommande = "",
    this.codePin,
    this.nomProduit = "Commande groupée",
    this.quantite = 1,
    this.pointRetrait = "Point de retrait DoGo Bamako",
    this.courtierNom = "Service Transit DoGo",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Code de Retrait Sécurisé",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Carte principale du QR Code et PIN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C46321E),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  // Statut Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "Colis disponible au point de retrait",
                          style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Simulation de QR Code stylisé
                  Container(
                    width: 200,
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5DDD5), width: 2),
                    ),
                    child: CustomPaint(
                      painter: _QrCodePainter(primaryColor: AppTheme.primaryDark),
                      child: const Center(
                        child: ContainerLogoBadge(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    codeCommande,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF0EAE4)),
                  const SizedBox(height: 16),

                  // Affichage du Code PIN ou consigne SMS (Conformité RG-71)
                  if (codePin != null && codePin!.isNotEmpty) ...[
                    const Text(
                      "VOTRE CODE PIN CONFIDENTIEL",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final digit = index < codePin!.length ? codePin![index] : '-';
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 50,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppTheme.tertiary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.primary,
                              width: 1.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              digit,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Badge explicatif SMS conforme RG-71
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sms_outlined, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            codePin != null && codePin!.isNotEmpty
                                ? "Code PIN également transmis par SMS au commerçant pour le retrait au guichet."
                                : "Code PIN confidentiel envoyé par SMS sur votre numéro. À dicter au guichet lors du scan du QR code.",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Un SMS avec votre code PIN de retrait vient d'être réexpédié."),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primary),
                    label: const Text(
                      "Renvoyer le code PIN par SMS",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: AppTheme.textMuted),
                      SizedBox(width: 5),
                      Text(
                        "À communiquer uniquement au guichet de retrait",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Détails du point relais et du courtier
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0846321E),
                    blurRadius: 15,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lieu de retrait",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppTheme.secondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pointRetrait,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Courtier responsable : $courtierNom",
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF3ECE5)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Article",
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      Text(
                        "$quantite unités",
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nomProduit,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sécurité et déblocage séquestre
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F5F0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.primary, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Vos fonds restent protégés jusqu'à votre retrait.",
                      style: TextStyle(fontSize: 11.5, height: 1.35, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContainerLogoBadge extends StatelessWidget {
  const ContainerLogoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text(
          "DG",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// Peintre géométrique de simulation de QR Code
class _QrCodePainter extends CustomPainter {
  final Color primaryColor;

  _QrCodePainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    // Coins repères (Finders)
    _drawFinderPattern(canvas, 0, 0, size.width * 0.28, paint);
    _drawFinderPattern(canvas, size.width * 0.72, 0, size.width * 0.28, paint);
    _drawFinderPattern(canvas, 0, size.height * 0.72, size.width * 0.28, paint);

    // Grille de pixels de données simulée
    final step = size.width / 14;
    for (int i = 0; i < 14; i++) {
      for (int j = 0; j < 14; j++) {
        // Éviter les coins repères et le centre logo
        final inTopLeft = i < 5 && j < 5;
        final inTopRight = i >= 9 && j < 5;
        final inBottomLeft = i < 5 && j >= 9;
        final inCenter = i >= 4 && i <= 9 && j >= 4 && j <= 9;

        if (!inTopLeft && !inTopRight && !inBottomLeft && !inCenter) {
          if ((i * 3 + j * 7 + (i * j)) % 3 == 0) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(i * step + 1, j * step + 1, step - 2, step - 2),
                const Radius.circular(2),
              ),
              paint,
            );
          }
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, double x, double y, double size, Paint paint) {
    // Carré externe
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, size, size), const Radius.circular(6)),
      paint,
    );
    // Carré blanc intermédiaire
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + size * 0.16, y + size * 0.16, size * 0.68, size * 0.68),
        const Radius.circular(4),
      ),
      whitePaint,
    );
    // Carré noir interne
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + size * 0.32, y + size * 0.32, size * 0.36, size * 0.36),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
