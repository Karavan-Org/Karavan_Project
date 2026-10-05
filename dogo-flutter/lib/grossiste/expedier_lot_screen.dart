import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran de remise du lot au Courtier / Transitaire
class ExpedierLotScreen extends StatefulWidget {
  const ExpedierLotScreen({super.key});

  @override
  State<ExpedierLotScreen> createState() => _ExpedierLotScreenState();
}

class _ExpedierLotScreenState extends State<ExpedierLotScreen> {
  String _selectedLot = "LOT-2026-BZN-04 (50 pièces - 18 commerçants)";
  final _poidsReelController = TextEditingController(text: "48.5");
  final _cartonsController = TextEditingController(text: "3");
  final _bordereauController = TextEditingController(text: "BRD-ZHEJ-2026-88");

  void _validerExpedition() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: AppTheme.primary, size: 28),
            SizedBox(width: 10),
            Text("Bordereau Généré !", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Le lot a été pris en charge par le transitaire logistique Touré Transit & Logistique.",
              style: TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _info("N° Bordereau :", _bordereauController.text),
                  _info("Poids pesé :", "${_poidsReelController.text} kg"),
                  _info("Cartons scellés :", "${_cartonsController.text} cartons"),
                  _info("Statut :", "Chez le Courtier"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Terminer"),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Remise Lot au Courtier", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  const Text("Sélectionner le lot prêt :", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLot,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: "LOT-2026-BZN-04 (50 pièces - 18 commerçants)",
                            child: Text("LOT-2026-BZN-04 (50 pcs)"),
                          ),
                          DropdownMenuItem(
                            value: "LOT-2026-ABY-01 (30 pièces - 8 commerçants)",
                            child: Text("LOT-2026-ABY-01 (30 pcs)"),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLot = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Poids pesé (kg)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _poidsReelController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: "kg",
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Nombre de colis", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _cartonsController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: "cartons",
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Code Scellé / Bordereau de remise", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bordereauController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _validerExpedition,
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text(
                  "Valider la Remise au Transitaire",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
