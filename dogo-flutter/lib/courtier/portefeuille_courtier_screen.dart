import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/zone_portefeuille_neumorphic.dart';

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
            // --- ZONE PORTEFEUILLE NEUMORPHIQUE SOFT 3D (Style Maquette) ---
            ZonePortefeuilleNeumorphic(
              titre: "Portefeuille Courtier",
              sousTitre: "Commissions de transit & convois sécurisées",
              montantSolde: "0 FCFA",
              infoSequestre: "Garantie Séquestre DoGo • Commissions débloquées à la livraison",
              iconeInfo: Icons.security_rounded,
              texteBoutonAction: "Retirer vers Mobile Money",
              onTapAction: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Solde insuffisant pour initier un retrait."),
                    backgroundColor: Color(0xFFC0392B),
                  ),
                );
              },
              couleurBouton: const [
                Color(0xFFC07A3E),
                Color(0xFF9E5C23),
                Color(0xFF7A4012),
              ],
              couleurEmbleme: const [
                Color(0xFFFFFFFF),
                Color(0xFFE5A100),
                Color(0xFF9E5C23),
              ],
              titreSquirclesRapides: "COMPTES DE RETRAIT",
              squirclesRapides: [
                ZonePortefeuilleNeumorphic.buildSquircleRapide(
                  label: "Orange",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Compte de retrait Orange Money sélectionné")),
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF7900),
                    ),
                    alignment: Alignment.center,
                    child: const Text("OM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 24),
                ZonePortefeuilleNeumorphic.buildSquircleRapide(
                  label: "Moov",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Compte de retrait Moov Money sélectionné")),
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF005DAA),
                    ),
                    alignment: Alignment.center,
                    child: const Text("MM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 24),
                ZonePortefeuilleNeumorphic.buildSquircleRapide(
                  label: "Wave",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Compte de retrait Wave sélectionné")),
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1DC4F2),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.waves_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
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
