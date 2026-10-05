import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran des Commandes & Expéditions du Grossiste (Lots remplis, Préparation & Remise Transitaire)
class GrossisteCommandesScreen extends StatefulWidget {
  const GrossisteCommandesScreen({super.key});

  @override
  State<GrossisteCommandesScreen> createState() => _GrossisteCommandesScreenState();
}

class _GrossisteCommandesScreenState extends State<GrossisteCommandesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _lotsEnCours = [
    {
      "lotId": "LOT-2026-BZN-04",
      "article": "Bazin Super Riche 10m Autriche",
      "totalPieces": 50,
      "piecesCommandees": 50,
      "commercants": 18,
      "valeurTotale": "2 100 000 FCFA",
      "statut": "À VALIDER (RG-18)",
      "statutColor": AppTheme.secondary,
      "transitaire": "Touré Transit (Maritime)",
    },
    {
      "lotId": "LOT-2026-SNK-12",
      "article": "Sneakers Chunky Sport Fashion 2026",
      "totalPieces": 100,
      "piecesCommandees": 85,
      "commercants": 12,
      "valeurTotale": "552 500 FCFA",
      "statut": "REMPLISSAGE (85%)",
      "statutColor": AppTheme.primary,
      "transitaire": "Dogo Cargo Express (Aérien)",
    },
    {
      "lotId": "LOT-2026-ABY-01",
      "article": "Robes Abayas Brodées Dubaï",
      "totalPieces": 30,
      "piecesCommandees": 30,
      "commercants": 8,
      "valeurTotale": "420 000 FCFA",
      "statut": "EXPÉDIÉ AU TRANSITAIRE",
      "statutColor": AppTheme.success,
      "transitaire": "Emirates Cargo Mali",
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Lots & Expéditions Grossiste",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.textDark,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "En cours (2)"),
            Tab(text: "À Valider (1)"),
            Tab(text: "Expédiés (8)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLotsList(_lotsEnCours),
          _buildLotsList(_lotsEnCours.where((l) => l["statut"].toString().contains("VALIDE")).toList()),
          _buildLotsList(_lotsEnCours.where((l) => l["statut"].toString().contains("EXPÉDIÉ")).toList()),
        ],
      ),
    );
  }

  Widget _buildLotsList(List<Map<String, dynamic>> lots) {
    if (lots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              "Aucun lot dans cette catégorie",
              style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: lots.length,
      itemBuilder: (context, index) {
        final lot = lots[index];
        final double ratio = (lot["piecesCommandees"] as int) / (lot["totalPieces"] as int);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lot["lotId"] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppTheme.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (lot["statutColor"] as Color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lot["statut"] as String,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: lot["statutColor"] as Color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lot["article"] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              // Jauge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${lot["piecesCommandees"]} / ${lot["totalPieces"]} pièces",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "${(ratio * 100).toInt()}%",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: AppTheme.tertiary.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(lot["statutColor"] as Color),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        "${lot["commercants"]} commerçants",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  Text(
                    lot["valeurTotale"] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    "Transitaire assigné : ${lot["transitaire"]}",
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
