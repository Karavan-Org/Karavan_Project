import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran Historiques du Grossiste (Ventes clôturées, Lots remis aux transitaires et versements)
class HistoriqueGrossisteScreen extends StatelessWidget {
  const HistoriqueGrossisteScreen({super.key});

  final List<Map<String, dynamic>> _historique = const [
    {
      "lot": "LOT-2026-BZN-04",
      "article": "Bazin Super Riche 10m Getzner",
      "destinataire": "Transitaire Touré Transit (Bamako)",
      "date": "10 sept. 2026",
      "pieces": "50 pièces",
      "montant": "+2 100 000 FCFA",
      "statut": "En transit maritime",
      "statutColor": AppTheme.primary,
    },
    {
      "lot": "LOT-2026-SNK-01",
      "article": "Sneakers Chunky Sport Fashion",
      "destinataire": "Dogo Cargo Express (Aérien)",
      "date": "04 sept. 2026",
      "pieces": "100 pièces",
      "montant": "+650 000 FCFA",
      "statut": "Livré & Soldé",
      "statutColor": AppTheme.success,
    },
    {
      "lot": "LOT-2026-ABY-08",
      "article": "Robes Abayas Brodées Dubaï",
      "destinataire": "Emirates Cargo Mali",
      "date": "28 août 2026",
      "pieces": "40 pièces",
      "montant": "+560 000 FCFA",
      "statut": "Livré & Soldé",
      "statutColor": AppTheme.success,
    },
    {
      "lot": "LOT-2026-BAG-02",
      "article": "Sacs à Main Cuir Verni Luxe",
      "destinataire": "Istanbul Express Fret",
      "date": "15 août 2026",
      "pieces": "60 pièces",
      "montant": "+552 000 FCFA",
      "statut": "Livré & Soldé",
      "statutColor": AppTheme.success,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C241E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Historiques des Ventes",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        itemCount: _historique.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _historique[index];

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEFE9E0)),
              boxShadow: const [
                BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item["lot"] as String,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF9E6738)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (item["statutColor"] as Color).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item["statut"] as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: item["statutColor"] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item["article"] as String,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2C241E)),
                ),
                const SizedBox(height: 4),
                Text(
                  "${item["destinataire"]} • ${item["date"]}",
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item["pieces"] as String,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5A493B), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item["montant"] as String,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.success),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
