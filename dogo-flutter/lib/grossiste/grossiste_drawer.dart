import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ajouter_produit_screen.dart';
import 'mes_groupes_grossiste_screen.dart';
import 'portefeuille_grossiste_screen.dart';
import 'parametres_grossiste_screen.dart';
import '../widgets/tab_navigation_scope.dart';
import '../services/api/api_config.dart';
import '../services/auth_service.dart';

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
      backgroundColor: AppTheme.couleurCarte(context),
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
              child: ValueListenableBuilder<UtilisateurProfil?>(
                valueListenable: AuthService.instance.profilNotifier,
                builder: (context, profil, _) {
                  final photoUrl = profil?.photoUrl;
                  final nomAffiche = (profil != null && profil.nom.trim().isNotEmpty) ? profil.nom : "Grossiste Partenaire";
                  final initiales = (profil != null && profil.nom.trim().isNotEmpty)
                      ? profil.nom.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                      : 'GR';

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(context);
                      TabNavigationScope.switchToTab(context, 3);
                    },
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                    ApiConfig.resolutionImageUrl(photoUrl),
                                    fit: BoxFit.cover,
                                    width: 52,
                                    height: 52,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        initiales,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      initiales,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomAffiche,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.couleurTexte(context),
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
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Chine",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppTheme.couleurTexteAttenue(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
                        TabNavigationScope.switchToTab(context, 0);
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
                      TabNavigationScope.switchToTab(context, 1);
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
                    icon: Icons.groups_rounded,
                    title: "Mes groupes d'achat",
                    isActive: activeRoute == 'groupes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MesGroupesGrossisteScreen()),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MesGroupesGrossisteScreen(
                            titre: "Disponibilités à valider",
                            filtreInitial: "À confirmer",
                          ),
                        ),
                      );
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
                      TabNavigationScope.switchToTab(context, 2);
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PortefeuilleGrossisteScreen()),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.settings_rounded,
                    title: "Paramètres & Entreprise",
                    isActive: activeRoute == 'settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ParametresGrossisteScreen()),
                      );
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
                  AuthService.instance.deconnecter();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/onboarding',
                    (route) => false,
                  );
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        dense: true,
        // Le fond de l'élément actif est peint par le ListTile lui-même (pas par un Container au-dessus du Material)
        tileColor: isActive ? AppTheme.primary.withValues(alpha: 0.12) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(
          icon,
          size: 22,
          color: isActive ? AppTheme.primary : AppTheme.couleurTexteAttenue(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppTheme.primary : AppTheme.couleurTexte(context),
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
                    fontSize: 11.5,
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
