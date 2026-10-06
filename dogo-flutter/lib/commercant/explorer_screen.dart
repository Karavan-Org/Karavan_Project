import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'campagne_model.dart';
import 'favoris_service.dart';
import 'fiche_campagne_screen.dart';

/// Écran Explorer pour le Commerçant (Découverte avancée, catégories, filtres pays)
class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  String _paysActif = "Tous";
  String _categorieActive = "Tous";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final List<String> _pays = ["Tous", "Chine 🇨🇳", "Turquie 🇹🇷", "Dubaï 🇦🇪"];
  final List<String> _categories = [
    "Tous",
    "Sneakers",
    "Mode Féminine",
    "Chaussures",
    "Montres & Bijoux",
  ];

  @override
  void initState() {
    super.initState();
    FavorisService.instance.actualiserDepuisBackend();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Explorer les Arrivages",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          FavorisService.instance.favorisNotifier,
          FavorisService.instance.campagnesNotifier,
        ]),
        builder: (context, _) {
          final favorisIds = FavorisService.instance.favorisNotifier.value;
          final toutesCampagnes = FavorisService.instance.toutesLesCampagnes;

          final filtrees = toutesCampagnes.where((c) {
            if (_categorieActive != "Tous" && c.categorie != _categorieActive) {
              return false;
            }
            if (_paysActif == "Chine 🇨🇳" && !c.paysOrigine.toLowerCase().contains("chine")) {
              return false;
            }
            if (_paysActif == "Turquie 🇹🇷" && !c.paysOrigine.toLowerCase().contains("turquie")) {
              return false;
            }
            if (_paysActif == "Dubaï 🇦🇪" && !c.paysOrigine.toLowerCase().contains("dubaï")) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              return c.titre.toLowerCase().contains(q) ||
                  c.sousTitre.toLowerCase().contains(q) ||
                  c.categorie.toLowerCase().contains(q) ||
                  c.courtierNom.toLowerCase().contains(q);
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () => FavorisService.instance.actualiserDepuisBackend(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2D9D0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search, color: AppTheme.textMuted),
                        hintText: "Rechercher par article, fournisseur ou pays...",
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        border: InputBorder.none,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = "");
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Filtres par Pays
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    "Hubs d'approvisionnement direct :",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: _pays.map((p) {
                      final isSelected = p == _paysActif;
                      return GestureDetector(
                        onTap: () => setState(() => _paysActif = p),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : const Color(0xFFE2D9D0),
                            ),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),

                // Filtres par Catégorie
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = cat == _categorieActive;
                      return GestureDetector(
                        onTap: () => setState(() => _categorieActive = cat),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.secondary : const Color(0xFFF7F2EB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppTheme.secondary : const Color(0xFFE5DDD5),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Liste en grille des résultats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Résultats (${filtrees.length} opportunités)",
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 12),

                if (filtrees.isEmpty)
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        "Aucun arrivage ne correspond à ces critères.",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtrees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final g = filtrees[index];
                        final isFav = favorisIds.contains(g.id);
                        return _buildItemExplorer(context, g, isFav);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }

  Widget _buildItemExplorer(BuildContext context, GroupeCampagneModel g, bool isFav) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FicheCampagneScreen(
              id: g.id,
              titre: g.titre,
              sousTitre: g.sousTitre,
              imagePath: g.imagePath,
              prixGroupe: g.prixGroupe,
              prixPublic: g.prixPublic,
              quantiteActuelle: g.quantiteActuelle,
              quantiteObjectif: g.quantiteObjectif,
              categorie: g.categorie,
              paysOrigine: g.paysOrigine,
              courtierNom: g.courtierNom,
              tempsRestant: g.tempsRestant,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFFF7F2EB),
                child: Image.asset(
                  g.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          g.paysOrigine,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : AppTheme.textMuted,
                          size: 18,
                        ),
                        onPressed: () => FavorisService.instance.toggleFavori(g, context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    g.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  Text(
                    "Courtier : ${g.courtierNom}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${g.prixGroupe} FCFA",
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary, fontSize: 13.5),
                      ),
                      Text(
                        "${(g.ratio * 100).toInt()}% réservé",
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
