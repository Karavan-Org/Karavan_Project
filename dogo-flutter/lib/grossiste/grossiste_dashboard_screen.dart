import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ajouter_produit_screen.dart';
import 'grossiste_drawer.dart';

/// Tableau de bord d'accueil du Grossiste (Section 2 de la planche)
class GrossisteDashboardScreen extends StatelessWidget {
  final bool showFab;

  const GrossisteDashboardScreen({
    super.key,
    this.showFab = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const GrossisteDrawer(activeRoute: 'dashboard'),
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.textDark, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo_dogo.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(Icons.store, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Espace Grossiste",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textDark),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Aucune nouvelle notification."),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AjouterProduitScreen()),
                );
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Ajouter produit"),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CARTE ALERTE VALIDATION DE DISPONIBILITÉ (RG-18) ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF8E7), Color(0xFFFFF3D6)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, color: AppTheme.secondary, size: 24),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Disponibilité à confirmer (RG-18)",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF6D4C00)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Un groupe d'achat (Sneakers Pro - 50 paires) attend votre validation de stock.",
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF8A6516)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Disponibilité de stock attestée avec succès pour le groupe !"),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(60, 36),
                    ),
                    child: const Text("Valider", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- CARTES STATISTIQUES ET KPIS ---
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: "Chiffre d'Affaires",
                    value: "0 F",
                    subtext: "Séquestre garanti",
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: "Commandes Groupées",
                    value: "0",
                    subtext: "0 prête à expédier",
                    icon: Icons.local_shipping_rounded,
                    iconColor: AppTheme.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- EN-TÊTE SECTION MON CATALOGUE ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Mon Catalogue Actif",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textDark),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AjouterProduitScreen()),
                    );
                  },
                  child: const Text("Ajouter", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // --- ÉTAT VIDE CATALOGUE ACTIF ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEFE9E0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    "Aucun article actif dans le catalogue",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Cliquez sur \"Ajouter produit\" pour publier vos lots à destination des commerçants.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE8E0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 2),
          Text(subtext, style: const TextStyle(fontSize: 11.5, color: AppTheme.success, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
