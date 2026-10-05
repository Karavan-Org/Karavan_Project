import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran du Catalogue Grossiste (Stocks, Paliers de prix et MOQ)
class GrossisteCatalogueScreen extends StatefulWidget {
  const GrossisteCatalogueScreen({super.key});

  @override
  State<GrossisteCatalogueScreen> createState() => _GrossisteCatalogueScreenState();
}

class _GrossisteCatalogueScreenState extends State<GrossisteCatalogueScreen> {
  String _selectedCategory = "Tous";

  final List<Map<String, dynamic>> _articles = [
    {
      "nom": "Bazin Riche Getzner Authentique 10m",
      "categorie": "Textile",
      "origine": "Autriche / Dubai",
      "stock": 140,
      "moq": 10,
      "prixGros": "42 000 FCFA",
      "prixPublic": "65 000 FCFA",
      "groupeActif": true,
      "image": "assets/images/logo_dogo.png",
    },
    {
      "nom": "Sneakers Chunky Sport Fashion 2026",
      "categorie": "Chaussures",
      "origine": "Guangzhou (Chine)",
      "stock": 450,
      "moq": 25,
      "prixGros": "6 500 FCFA",
      "prixPublic": "12 000 FCFA",
      "groupeActif": true,
      "image": "assets/images/Nike_Joyride-removebg-preview.png",
    },
    {
      "nom": "Robes Abayas Brodées Dubaï Collection",
      "categorie": "Mode",
      "origine": "Dubaï (Émirats)",
      "stock": 85,
      "moq": 12,
      "prixGros": "14 000 FCFA",
      "prixPublic": "22 500 FCFA",
      "groupeActif": false,
      "image": "assets/images/soft-elegance-abaya-coat-nida-purple-noor-and-grace.webp",
    },
    {
      "nom": "Lots Sacs à Main Cuir Verni Luxe",
      "categorie": "Maroquinerie",
      "origine": "Istanbul (Turquie)",
      "stock": 210,
      "moq": 20,
      "prixGros": "9 200 FCFA",
      "prixPublic": "16 000 FCFA",
      "groupeActif": true,
      "image": "assets/images/wallet.jpg",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == "Tous"
        ? _articles
        : _articles.where((a) => a["categorie"] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Mon Catalogue Grossiste",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.textDark),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Recherche dans le catalogue grossiste...")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.textDark),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Filtres avancés : Affichage par disponibilité et MOQ.")),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filtres par catégorie
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ["Tous", "Textile", "Chaussures", "Mode", "Maroquinerie"].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textDark,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : const Color(0xFFE5DDD5),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Liste des articles
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Miniature avec gestion d'image réelle et fallback errorBuilder
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.tertiary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            item["image"] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(
                                Icons.inventory_2_rounded,
                                color: AppTheme.primary,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Infos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tertiary.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item["origine"] as String,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                                if (item["groupeActif"] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Groupe en cours",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item["nom"] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  item["prixGros"] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.5,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Stock : ${item["stock"]} pcs",
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "MOQ : ${item["moq"]} pièces minimum",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
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
        ],
      ),
    );
  }
}
