import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran Historiques du Courtier (Convois clôturés, décharges et commissions libérées)
class HistoriqueCourtierScreen extends StatelessWidget {
  const HistoriqueCourtierScreen({super.key});

  final List<Map<String, dynamic>> _historique = const [];

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
          "Historique des Convois",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
      ),
      body: _historique.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Aucun convoi dans l'historique",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF2C241E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Les convois acheminés et clôturés apparaîtront ici.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
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
                      item["convoi"] as String,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF9E6738)),
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
                  item["trajet"] as String,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2C241E)),
                ),
                const SizedBox(height: 4),
                Text(
                  "${item["colis"]} • Clôturé le ${item["date"]}",
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Commission perçue :",
                      style: TextStyle(fontSize: 12, color: Color(0xFF5A493B), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item["commission"] as String,
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
