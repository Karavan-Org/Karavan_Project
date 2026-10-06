import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran de Mise à Jour Rapide des Jalons Logistiques (Courtier / Transitaire)
class EtapeTransitScreen extends StatefulWidget {
  const EtapeTransitScreen({super.key});

  @override
  State<EtapeTransitScreen> createState() => _EtapeTransitScreenState();
}

class _EtapeTransitScreenState extends State<EtapeTransitScreen> {
  final List<Map<String, dynamic>> _convois = [];

  final List<String> _etapes = [
    "Enlèvement entrepôt usine",
    "Fret International en cours",
    "Arrivée Douanes Bamako",
    "Déchargé au Dépôt Dabanani",
    "Prêt au retrait sécurisé",
  ];

  void _validerProgression(int convoiIndex) {
    final convoi = _convois[convoiIndex];
    final int current = convoi["etapeActuelle"] as int;
    if (current < _etapes.length) {
      setState(() {
        convoi["etapeActuelle"] = current + 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Jalon validé : \"${_etapes[current]}\" ! ${convoi["colisCount"]} commerçants ont reçu une notification SMS.",
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Mise à Jour Jalon Transit", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E2832), Color(0xFF2C3E50)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.cell_tower_rounded, color: AppTheme.secondary, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    "Chaque étape validée prévient les commerçants par SMS.",
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_convois.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEFE8DD), width: 1.2),
              ),
              child: Column(
                children: [
                  Icon(Icons.alt_route_rounded, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    "Aucun convoi actif",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF2C241E)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Les convois en cours d'acheminement apparaîtront ici pour le pointage des étapes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            )
          else ...[
            const Text("Sélectionner le convoi à pointer :", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 12),
            ...List.generate(_convois.length, (index) {
            final c = _convois[index];
            final int step = c["etapeActuelle"] as int;
            final isCompleted = step >= _etapes.length;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c["code"] as String, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.tertiary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c["mode"] as String,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(c["trajet"] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Text("${c["colisCount"]} colis groupés • Poids : ${c["poidsTotal"]}", style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 14),
                  // Étapes visuelles
                  Column(
                    children: List.generate(_etapes.length, (sIndex) {
                      final bool isDone = sIndex < step;
                      final bool isCurrent = sIndex == step - 1;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isDone ? Icons.check_circle_rounded : (isCurrent ? Icons.radio_button_checked : Icons.radio_button_off),
                              size: 18,
                              color: isDone ? AppTheme.success : (isCurrent ? AppTheme.primary : const Color(0xFFD4C5B9)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Étape ${sIndex + 1} : ${_etapes[sIndex]}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                                  color: isDone || isCurrent ? AppTheme.textDark : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (!isCompleted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _validerProgression(index),
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        label: Text(
                          "Pointer Étape ${step + 1} : ${_etapes[step]}",
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
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
                        "✓ Tous les colis de ce convoi sont arrivés à destination",
                        style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
        ],
      ),
    );
  }
}
