import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran Portefeuille Courtier (Frame 17 de la planche)
class PortefeuilleCourtierScreen extends StatelessWidget {
  const PortefeuilleCourtierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Portefeuille Courtier", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CARTE PRINCIPALE SOLDE DISPONIBLE ---
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C241E), Color(0xFF45362C)],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 15, offset: Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Commissions prêtes au retrait", style: TextStyle(color: Color(0xFFD4C5B9), fontSize: 12.5)),
                  const SizedBox(height: 8),
                  const Text("0 FCFA", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Solde insuffisant pour initier un virement."),
                          backgroundColor: Color(0xFFC0392B),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text("Retirer vers Mobile Money", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- COMPTES DE VERSEMENT ENREGISTRÉS ---
            const Text("Comptes de Versement Associés", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),

            _buildMoyenCard("Orange Money", "Compte Principal (Par défaut)", true, Icons.phone_android_rounded),
            const SizedBox(height: 10),
            _buildMoyenCard("Moov Money", "Compte Secondaire", false, Icons.phone_android_rounded),

            const SizedBox(height: 24),

            // --- HISTORIQUE DES MOUVEMENTS DE COMMISSIONS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Historique des Mouvements", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Filtres : Toutes vos commissions et retraits sont affichés."),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text("Filtrer", style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEFE8DD), width: 1.2),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    "Aucune commission pour le moment",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Vos commissions de transit apparaîtront ici dès l'arrivée des premiers convois.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMoyenCard(String operateur, String numero, bool isDefault, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFE8E0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.tertiary.withValues(alpha: 0.4),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(operateur, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(numero, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("Par défaut", style: TextStyle(color: AppTheme.success, fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
