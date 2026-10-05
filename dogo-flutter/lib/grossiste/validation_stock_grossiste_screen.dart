import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran de Validation de Disponibilité des Stocks (Règle Métier RG-18)
/// Le grossiste dispose de 24h pour confirmer le stock physique avant déclenchement du séquestre et emballage
class ValidationStockGrossisteScreen extends StatefulWidget {
  const ValidationStockGrossisteScreen({super.key});

  @override
  State<ValidationStockGrossisteScreen> createState() => _ValidationStockGrossisteScreenState();
}

class _ValidationStockGrossisteScreenState extends State<ValidationStockGrossisteScreen> {
  final List<Map<String, dynamic>> _demandes = [
    {
      "id": "CMD-BZN-8891",
      "article": "Bazin Riche Getzner Authentique 10m",
      "quantite": 50,
      "valeur": "2 100 000 FCFA",
      "delaiRestant": "14h 22m",
      "commercants": 18,
      "confirme": false,
    },
    {
      "id": "CMD-SNK-4012",
      "article": "Sneakers Chunky Sport Fashion 2026 (Tailles 40-45)",
      "quantite": 100,
      "valeur": "650 000 FCFA",
      "delaiRestant": "21h 05m",
      "commercants": 14,
      "confirme": false,
    },
  ];

  void _confirmerStock(int index) {
    setState(() {
      _demandes[index]["confirme"] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Stock confirmé pour ${_demandes[index]["id"]} ! Le séquestre est sécurisé et le bordereau courtier est généré.",
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Validation Disponibilité (RG-18)",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Explication RG-18
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E7), Color(0xFFFFF1D0)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_outlined, color: AppTheme.secondary, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Délai d'engagement : 24 heures",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textDark),
                      ),
                      SizedBox(height: 3),
                      Text(
                        "Confirmez votre stock pour débloquer l'expédition.",
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Groupes remplis en attente de confirmation :",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark),
          ),

          const SizedBox(height: 12),

          ...List.generate(_demandes.length, (index) {
            final dem = _demandes[index];
            final bool isConfirme = dem["confirme"] as bool;

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
                        dem["id"] as String,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isConfirme
                              ? AppTheme.success.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isConfirme ? Icons.check_circle : Icons.hourglass_top_rounded,
                              size: 13,
                              color: isConfirme ? AppTheme.success : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isConfirme ? "VALIDÉ" : "Reste ${dem["delaiRestant"]}",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isConfirme ? AppTheme.success : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dem["article"] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${dem["quantite"]} pièces (${dem["commercants"]} commerçants)",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      Text(
                        dem["valeur"] as String,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!isConfirme)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Rupture signalée. Les commerçants seront remboursés du séquestre.")),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Color(0xFFFFCDD2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Rupture stock"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmerStock(index),
                            icon: const Icon(Icons.check, color: Colors.white, size: 18),
                            label: const Text(
                              "Confirmer Stock",
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "✓ Stock confirmé • Prêt pour le courtier",
                        style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
