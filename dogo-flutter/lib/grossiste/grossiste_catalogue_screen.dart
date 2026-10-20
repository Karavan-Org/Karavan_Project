import '../widgets/tab_navigation_scope.dart';
import 'package:flutter/material.dart';
import '../services/api/api_config.dart';
import '../services/catalogue_api_service.dart';
import '../theme/app_theme.dart';
import 'ajouter_produit_screen.dart';
import 'creer_groupe_grossiste_screen.dart';

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
    CatalogueApiService.instance.revision.addListener(_chargerProduits);
    _chargerProduits();
  }

  @override
  void dispose() {
    CatalogueApiService.instance.revision.removeListener(_chargerProduits);
    super.dispose();
  }

  Future<void> _chargerProduits() async {
    setState(() => _isLoading = true);
    try {
      final produitsServeur = await CatalogueApiService.instance.mesProduits();
      if (!mounted) return;
      setState(() {
        _articles = produitsServeur.map<Map<String, dynamic>>((p) {
          final variantes = ((p['variantes'] as List?) ?? []).cast<Map>();
          final stock = variantes.fold<int>(0, (t, v) => t + ((v['qteDisponible'] as num?) ?? 0).toInt());
          String liste(String cle) =>
              variantes.map((v) => v[cle]?.toString() ?? '').where((x) => x.isNotEmpty).toSet().join(', ');
          final tailles = liste('taille');
          final couleurs = liste('couleur');
          final prixGros = p['prixGros'];
          return {
            "produit": Map<String, dynamic>.from(p as Map),
            "id": p['id'],
            "nom": p['nom'] ?? 'Produit sans nom',
            "description": p['description'] ?? '',
            "categorie": "Tous",
            "origine": p['paysOrigine'] ?? '',
            "prixGros": prixGros is num
                ? "${prixGros.round()} F / pce"
                : "${variantes.length} variante${variantes.length > 1 ? 's' : ''}",
            "stock": stock,
            "resume": [
              if (tailles.isNotEmpty) "Tailles : $tailles",
              if (couleurs.isNotEmpty) "Couleurs : $couleurs",
            ].join(" • "),
            "groupeActif": false,
            "image": p['photoUrl'] ?? '',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _articles = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de charger votre catalogue : $e")),
      );
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
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),
        backgroundColor: AppTheme.couleurCarte(context),
        elevation: 0,
        centerTitle: false,
        title: Text(
          "Mon Catalogue Grossiste",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.couleurTexte(context),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.couleurTexte(context)),
            tooltip: "Actualiser le catalogue",
            onPressed: _chargerProduits,
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, color: AppTheme.couleurTexte(context)),
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
        heroTag: 'fab-catalogue-grossiste',
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
                    backgroundColor: AppTheme.couleurCarte(context),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.couleurTexte(context),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : AppTheme.couleurBordure(context),
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
                              Text(
                                "Aucun article dans le catalogue",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16.5,
                                  color: AppTheme.couleurTexte(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Ajoutez vos premiers articles avec photo pour créer vos groupes d'approvisionnement.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.couleurTexteAttenue(context),
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
                              color: AppTheme.couleurCarte(context),
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
                                              style: TextStyle(
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppTheme.couleurTexte(context),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            item["prixGros"] as String,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14.5,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Stock : ${item["stock"]} pcs",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: AppTheme.couleurTexteAttenue(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item["resume"] as String,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppTheme.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreerGroupeGrossisteScreen(
                                                produit: item["produit"] as Map<String, dynamic>,
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(Icons.group_add_rounded, size: 18),
                                          label: const Text("Créer un groupe"),
                                          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
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
