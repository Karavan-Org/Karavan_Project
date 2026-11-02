import '../widgets/tab_navigation_scope.dart';
import '../widgets/image_produit.dart';
import '../widgets/drapeau_pays_widget.dart';
import '../services/pays_resolver_service.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bouton_bascule_theme.dart';
import 'campagne_model.dart';
import 'favoris_service.dart';
import 'fiche_campagne_screen.dart';
import 'ouvrir_groupe_screen.dart';

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

  /// Pays d'origine et catégories des groupes réellement publiés : les filtres suivent le catalogue vivant
  /// et ne proposent jamais une valeur sans résultat.
  static String _cle(String s) => s.trim().toLowerCase();

  /// « CN », « China » et « Chine » désignent le même pays : une seule puce, au nom officiel.
  static String _clePays(String s) {
    final info = PaysResolverService.instance.resoudre(s);
    return info.estReconnu ? info.codeIso : _cle(s);
  }

  List<String> get _pays {
    final vus = <String, String>{};
    for (final c in FavorisService.instance.toutesLesCampagnes) {
      final p = c.paysOrigine.trim();
      if (p.isNotEmpty) vus.putIfAbsent(_clePays(p), () => PaysResolverService.instance.resoudre(p).nomFr);
    }
    return ["Tous", ...vus.values];
  }

  List<String> get _categories {
    final vues = <String, String>{};
    for (final c in FavorisService.instance.toutesLesCampagnes) {
      final cat = c.categorie.trim();
      if (cat.isNotEmpty) vues.putIfAbsent(_cle(cat), () => cat);
    }
    return ["Tous", ...vues.values];
  }

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        title: const Text(
          "Explorer les Arrivages",
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          const BoutonBasculeTheme(compact: true),
          IconButton(
            icon: const Icon(Icons.link_rounded),
            tooltip: "Rejoindre via un lien",
            onPressed: () => OuvrirGroupeScreen.saisirLien(context),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          FavorisService.instance.favorisNotifier,
          FavorisService.instance.campagnesNotifier,
        ]),
        builder: (context, _) {
          final favorisIds = FavorisService.instance.favorisNotifier.value;
          final toutesCampagnes = FavorisService.instance.toutesLesCampagnes;

          // Un filtre dont la valeur a disparu après une actualisation retombe sur « Tous »
          if (!_pays.contains(_paysActif)) _paysActif = "Tous";
          if (!_categories.contains(_categorieActive)) _categorieActive = "Tous";

          final filtrees = toutesCampagnes.where((c) {
            if (_categorieActive != "Tous" && _cle(c.categorie) != _cle(_categorieActive)) {
              return false;
            }
            if (_paysActif != "Tous" && _clePays(c.paysOrigine) != _clePays(_paysActif)) {
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search, color: AppTheme.couleurTexteAttenue(context)),
                        hintText: "Rechercher par article, fournisseur ou pays...",
                        hintStyle: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    "Hubs d'approvisionnement direct :",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.couleurTexte(context),
                    ),
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
                            color: isSelected ? AppTheme.terre : AppTheme.couleurCarte(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.terre : AppTheme.couleurBordure(context),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (p != "Tous") ...[
                                DrapeauPays(pays: p, largeur: 16, hauteur: 11),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                p,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? Colors.white : AppTheme.couleurTexte(context),
                                ),
                              ),
                            ],
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
                            color: isSelected ? AppTheme.secondary : AppTheme.couleurSurfaceDouce(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppTheme.secondary : AppTheme.couleurBordure(context),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppTheme.terre : AppTheme.couleurTexte(context),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.couleurTexte(context),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (filtrees.isEmpty)
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: AppTheme.couleurCarte(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        "Aucun arrivage ne correspond à ces critères.",
                        style: TextStyle(color: AppTheme.couleurTexteAttenue(context), fontSize: 13),
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
              groupe: g,
              variantes: g.variantes,
              quantiteMin: g.quantiteMinParCommercant,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 80,
                height: 80,
                color: AppTheme.couleurSurfaceDouce(context),
                child: imageProduit(
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
                      DrapeauBadge(
                        pays: g.paysOrigine,
                        compact: true,
                      ),
                      const Spacer(),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? AppTheme.danger : AppTheme.couleurTexteAttenue(context),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppTheme.couleurTexte(context),
                    ),
                  ),
                  Text(
                    "Courtier : ${g.courtierNom}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          "${g.prixGroupe} FCFA",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "${(g.ratio * 100).toInt()}% réservé",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: AppTheme.couleurTexteAttenue(context),
                          ),
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
    );
  }
}
