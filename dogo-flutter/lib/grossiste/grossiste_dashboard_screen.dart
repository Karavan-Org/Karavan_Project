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
            icon: const Badge(
              label: Text("2"),
              child: Icon(Icons.notifications_none_rounded, color: AppTheme.textDark),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Notifications : 2 nouvelles demandes d'approvisionnement en attente."),
                  duration: Duration(seconds: 3),
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
                    value: "8 450 000 F",
                    subtext: "Séquestre garanti",
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: "Commandes Groupées",
                    value: "24",
                    subtext: "12 prêtes à expédier",
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
                  child: const Text("Voir tout", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // --- LISTE DES PRODUITS EN VENTE AVEC ASSETS DU PROJET ---
            _buildProductRow(
              context: context,
              imagePath: "assets/images/Nike_Joyride-removebg-preview.png",
              nom: "Nike Joyride - Edition Pro",
              categorie: "Chaussures Sport",
              prix: "18 750 FCFA",
              stock: "420 unités disponibles",
              statusBadge: "En Campagne",
              badgeColor: AppTheme.secondary,
            ),
            const SizedBox(height: 12),
            _buildProductRow(
              context: context,
              imagePath: "assets/images/black-dress-boots-2-mob.jpg",
              nom: "Bottes Cuir Élégance Homme",
              categorie: "Maroquinerie & Bottes",
              prix: "24 000 FCFA",
              stock: "180 unités disponibles",
              statusBadge: "Stock Validé",
              badgeColor: AppTheme.success,
            ),
            const SizedBox(height: 12),
            _buildProductRow(
              context: context,
              imagePath: "assets/images/sandales-talon-rouge.jpg",
              nom: "Sandales Soirée à Talon Rouge",
              categorie: "Mode & Soirée",
              prix: "14 500 FCFA",
              stock: "95 unités disponibles",
              statusBadge: "Actif",
              badgeColor: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            _buildProductRow(
              context: context,
              imagePath: "assets/images/Montre-Homme-Quartz-Acier-Inoxydable-Cadran-Rond-Affichage-Analogique-Et-Num-rique-Boucle-Pliante-Simple-Cristal-Renforc-Nihaojewelry-France.webp",
              nom: "Montre Quartz Acier Inoxydable",
              categorie: "Accessoires & Horlogerie",
              prix: "9 800 FCFA",
              stock: "350 unités disponibles",
              statusBadge: "Actif",
              badgeColor: AppTheme.primary,
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

  Widget _buildProductRow({
    required BuildContext context,
    required String imagePath,
    required String nom,
    required String categorie,
    required String prix,
    required String stock,
    required String statusBadge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFE8E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nom,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusBadge,
                        style: TextStyle(color: badgeColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(categorie, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      prix,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 13.5),
                    ),
                    Text(stock, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
