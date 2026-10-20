import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran Historiques du Grossiste (Ventes clôturées, Lots remis aux transitaires et versements)
class HistoriqueGrossisteScreen extends StatelessWidget {
  const HistoriqueGrossisteScreen({super.key});

  final List<Map<String, dynamic>> _historique = const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Historiques des Ventes",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
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
                    Text(
                      "Aucune vente dans l'historique",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.couleurTexte(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Vos lots vendus et livrés aux transitaires s'afficheront ici.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
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
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.couleurBordure(context)),
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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.couleurTexte(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  "${item["destinataire"]} • ${item["date"]}",
                  style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item["pieces"] as String,
                      style: TextStyle(fontSize: 12, color: AppTheme.couleurTexte(context), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item["montant"] as String,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.success),
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
