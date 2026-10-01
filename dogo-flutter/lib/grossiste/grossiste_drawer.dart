import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ajouter_produit_screen.dart';
import 'grossiste_dashboard_screen.dart';

/// Menu Burger latéral du Grossiste (Drawer)
class GrossisteDrawer extends StatelessWidget {
  final String activeRoute;

  const GrossisteDrawer({
    super.key,
    this.activeRoute = 'dashboard',
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- EN-TÊTE DU PROFIL ENTREPRISE ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Zhejiang Footwear Co.",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    size: 11,
                                    color: AppTheme.success,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    "KYC Validé",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "Chine",
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // --- NAVIGATION DU MENU BURGER ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.dashboard_rounded,
                    title: "Tableau de bord",
                    isActive: activeRoute == 'dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      if (activeRoute != 'dashboard') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GrossisteDashboardScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.inventory_2_rounded,
                    title: "Mon Catalogue",
                    badge: "12",
                    isActive: activeRoute == 'catalogue',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.add_circle_outline_rounded,
                    title: "Ajouter un produit",
                    isActive: activeRoute == 'ajouter_produit',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AjouterProduitScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.fact_check_rounded,
                    title: "Disponibilités à valider",
                    badge: "3",
                    badgeColor: AppTheme.secondary,
                    isActive: activeRoute == 'disponibilites',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.local_shipping_rounded,
                    title: "Commandes à expédier",
                    badge: "1",
                    badgeColor: AppTheme.success,
                    isActive: activeRoute == 'expeditions',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFFEFE9E2)),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.account_balance_wallet_rounded,
                    title: "Portefeuille & Ventes",
                    isActive: activeRoute == 'finances',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.settings_rounded,
                    title: "Paramètres & Entreprise",
                    isActive: activeRoute == 'settings',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // --- PIED DE PAGE : DÉCONNEXION ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text("Déconnexion"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(
          icon,
          size: 22,
          color: isActive ? AppTheme.primary : AppTheme.textMuted,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppTheme.primaryDark : AppTheme.textDark,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor ?? AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
