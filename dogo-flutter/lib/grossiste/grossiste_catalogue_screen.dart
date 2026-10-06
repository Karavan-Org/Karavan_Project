import 'package:flutter/material.dart';
import '../services/api/api_config.dart';
import '../services/catalogue_api_service.dart';
import '../theme/app_theme.dart';
import 'ajouter_produit_screen.dart';

/// Écran du Catalogue Grossiste (Stocks, Paliers de prix, MOQ et Affichage des Photos Produits)
class GrossisteCatalogueScreen extends StatefulWidget {
  const GrossisteCatalogueScreen({super.key});

  @override
  State<GrossisteCatalogueScreen> createState() => _GrossisteCatalogueScreenState();
}

class _GrossisteCatalogueScreenState extends State<GrossisteCatalogueScreen> {
  String _selectedCategory = "Tous";
  bool _isLoading = false;
  List<Map<String, dynamic>> _articles = [];

  @override
  void initState() {
    super.initState();
    _chargerProduits();
  }

  Future<void> _chargerProduits() async {
    setState(() => _isLoading = true);
    try {
      final produitsServeur = await CatalogueApiService.instance.mesProduits();
      if (mounted) {
        if (produitsServeur.isNotEmpty) {
          final mapped = produitsServeur.map<Map<String, dynamic>>((p) {
            final variantes = (p['variantes'] as List?) ?? [];
            int totalStock = 0;
            for (var v in variantes) {
              totalStock += (v['qteDisponible'] as num? ?? 0).toInt();
            }

            return {
              "id": p['id'],
              "nom": p['nom'] ?? 'Produit sans nom',
              "description": p['description'] ?? '',
              "categorie": "Tous",
              "origine": p['paysOrigine'] ?? "Mali",
              "prixGros": "Prix catalogue",
              "stock": totalStock > 0 ? totalStock : 50,
              "moq": 10,
              "groupeActif": true,
              "image": p['photoUrl'] ?? "assets/images/Nike_Joyride-removebg-preview.png",
            };
          }).toList();

          setState(() {
            _articles = mapped;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {
      // Fallback gracieux en mode hors-ligne
    }

    if (mounted) {
      setState(() {
        _articles = [
          {
            "id": 1,
            "nom": "Baskets Running Nike Joyride Dual Run",
            "description": "Technologie amorti microbilles, coloris blanc et bleu turquoise",
            "categorie": "Chaussures",
            "origine": "Vietnam",
            "prixGros": "24 500 XOF",
            "stock": 350,
            "moq": 20,
            "groupeActif": true,
            "image": "assets/images/Nike_Joyride-removebg-preview.png",
          },
          {
            "id": 2,
            "nom": "Bottines Chelsea Cuir Véritable Homme",
            "description": "Cuir pleine fleur noir, semelle cousue Goodyear",
            "categorie": "Chaussures",
            "origine": "Turquie",
            "prixGros": "32 000 XOF",
            "stock": 180,
            "moq": 15,
            "groupeActif": false,
            "image": "assets/images/black-dress-boots-2-mob.jpg",
          },
          {
            "id": 3,
            "nom": "Sandales à Talon Soirée Rouge Rubis",
            "description": "Finition velours, talon 8cm, fermeture boucle dorée",
            "categorie": "Chaussures",
            "origine": "Italie",
            "prixGros": "18 000 XOF",
            "stock": 240,
            "moq": 25,
            "groupeActif": true,
            "image": "assets/images/sandales-talon-rouge.jpg",
          },
          {
            "id": 4,
            "nom": "Montre Quartz Homme Acier Inoxydable",
            "description": "Cadran rond analogique, étanche 50m, cristal renforcé",
            "categorie": "Mode",
            "origine": "Chine",
            "prixGros": "12 500 XOF",
            "stock": 500,
            "moq": 50,
            "groupeActif": true,
            "image": "assets/images/Montre-Homme-Quartz-Acier-Inoxydable-Cadran-Rond-Affichage-Analogique-Et-Num-rique-Boucle-Pliante-Simple-Cristal-Renforc-Nihaojewelry-France.webp",
          },
        ];
        _isLoading = false;
      });
    }
  }

  Widget _buildImageProduit(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const Center(
        child: Icon(Icons.inventory_2_rounded, color: AppTheme.primary, size: 32),
      );
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://') || imagePath.startsWith('/api/')) {
      final fullUrl = ApiConfig.resolutionImageUrl(imagePath);
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          );
        },
      );
    }

    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.inventory_2_rounded, color: AppTheme.primary, size: 32),
      ),
    );
  }

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
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textDark),
            tooltip: "Actualiser le catalogue",
            onPressed: _chargerProduits,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.textDark),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Recherche dans le catalogue grossiste...")),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text(
          "Ajouter un article",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () async {
          final resultat = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AjouterProduitScreen()),
          );
          if (resultat == true) {
            _chargerProduits();
          }
        },
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.tertiary.withValues(alpha: 0.35),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 52,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                "Aucun article dans le catalogue",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16.5,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Ajoutez vos premiers articles avec photo pour créer vos groupes d'approvisionnement.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final resultat = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AjouterProduitScreen()),
                                  );
                                  if (resultat == true) {
                                    _chargerProduits();
                                  }
                                },
                                icon: const Icon(Icons.add_a_photo_rounded),
                                label: const Text("Ajouter mon premier produit"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
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
                                // Miniature avec support URL réseau serveur & Assets
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: AppTheme.tertiary.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildImageProduit(item["image"] as String?),
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
