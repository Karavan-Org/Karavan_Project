import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Formulaire de création / lancement d'un convoiement (Frame 10 de la planche Courtier)
class LancerConvoiScreen extends StatefulWidget {
  const LancerConvoiScreen({super.key});

  @override
  State<LancerConvoiScreen> createState() => _LancerConvoiScreenState();
}

class _LancerConvoiScreenState extends State<LancerConvoiScreen> {
  final _nomController = TextEditingController();
  final _pointDepartController = TextEditingController();
  final _pointArriveeController = TextEditingController();
  final _capaciteController = TextEditingController();
  final _tarifKgController = TextEditingController();

  int _selectedDelai = 8; // 8 jours

  @override
  void dispose() {
    _nomController.dispose();
    _pointDepartController.dispose();
    _pointArriveeController.dispose();
    _capaciteController.dispose();
    _tarifKgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Lancer un convoiement", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau d'information
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Fixez la capacité et le tarif du convoi.",
                      style: TextStyle(fontSize: 12, color: AppTheme.primaryDark),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildTextField("Intitulé du groupe d'acheminement", _nomController, Icons.local_shipping_rounded),
            const SizedBox(height: 14),
            _buildTextField("Point d'enlèvement (Origine)", _pointDepartController, Icons.flight_takeoff_rounded),
            const SizedBox(height: 14),
            _buildTextField("Point de distribution (Dépôt)", _pointArriveeController, Icons.place_rounded),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildTextField("Capacité maxi (Colis)", _capaciteController, Icons.inventory_2_rounded,
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField("Tarif (FCFA / kg)", _tarifKgController, Icons.payments_rounded,
                      keyboardType: TextInputType.number),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text("Délai d'enregistrement avant clôture", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [3, 5, 8, 15].map((d) {
                final isSelected = d == _selectedDelai;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDelai = d),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : const Color(0xFFE2D8CF),
                        ),
                      ),
                      child: Text(
                        "$d jours",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: AppTheme.success, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Sécurisation automatique DoGo", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                          "Vos commissions sont sécurisées en séquestre.",
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Convoi ouvert aux commerçants avec succès !"),
                    backgroundColor: AppTheme.success,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Ouvrir le groupe aux commerçants", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2D8CF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2D8CF)),
        ),
      ),
    );
  }
}
