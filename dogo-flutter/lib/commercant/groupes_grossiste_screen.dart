import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/drapeau_pays_widget.dart';
import 'favoris_service.dart';
import 'fiche_campagne_screen.dart';

/// Écran dédié aux Groupes d'Achat publiés par les Grossistes
/// Permet au Commerçant de parcourir, filtrer et rejoindre directement les groupes actifs
class GroupesGrossisteScreen extends StatefulWidget {
  const GroupesGrossisteScreen({super.key});

  @override
  State<GroupesGrossisteScreen> createState() => _GroupesGrossisteScreenState();
}

class _GroupesGrossisteScreenState extends State<GroupesGrossisteScreen> {
  String _grossisteFiltre = "Tous";
  String _categorieFiltre = "Tous";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final List<String> _grossistes = [
    "Tous",
    "Grossiste Cissé & Frères (Istanbul)",
    "Grossiste Diallo Import Guangzhou",
    "Grossiste Dubaï Fashion Ltd",
    "Grossiste Yiwu Commerce International",
    "Grossiste Ozkan Leather Istanbul",
  ];

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
    final estSombre = AppTheme.estSombre(context);
    final couleurFond = AppTheme.couleurFond(context);
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurSurfaceDouce = AppTheme.couleurSurfaceDouce(context);

    return Scaffold(
      backgroundColor: couleurFond,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Groupes des Grossistes",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: couleurTexte),
            ),
            Text(
              "Rejoignez un convoi actif et divisez vos coûts",
              style: TextStyle(fontSize: 11.5, color: couleurAttenue),
            ),
          ],
        ),
        backgroundColor: couleurCarte,
        foregroundColor: couleurTexte,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: couleurTexte, size: 24),
          tooltip: "Retour",
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
            tooltip: "Rejoindre par référence",
            onPressed: _showRechercheReferenceDialog,
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
          final tousGroupes = FavorisService.instance.toutesLesCampagnes;

          final groupesFiltres = tousGroupes.where((g) {
            if (_grossisteFiltre != "Tous" && g.grossisteNom != _grossisteFiltre) {
              return false;
            }
            if (_categorieFiltre != "Tous" && g.categorie != _categorieFiltre) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              return g.titre.toLowerCase().contains(q) ||
                  g.sousTitre.toLowerCase().contains(q) ||
                  g.grossisteNom.toLowerCase().contains(q) ||
                  g.paysOrigine.toLowerCase().contains(q);
            }
            return true;
          }).toList();

          return CustomScrollView(
            slivers: [
              // 1. Barre de recherche et filtre par référence
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: "Rechercher un produit, grossiste, pays...",
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: couleurSurfaceDouce,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: couleurBordure),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: couleurBordure),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Filtres par Grossiste Partenaire
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            "Grossistes importateurs :",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: couleurTexte),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: _grossistes.map((grossiste) {
                          final isSelected = _grossisteFiltre == grossiste;
                          final label = grossiste == "Tous" ? "Tous les grossistes" : grossiste;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _grossisteFiltre = grossiste),
                              backgroundColor: couleurSurfaceDouce,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : couleurTexte,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primary : couleurBordure,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Filtres par Catégorie
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _categorieFiltre == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _categorieFiltre = cat),
                          backgroundColor: couleurSurfaceDouce,
                          selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.primary : couleurAttenue,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primary : couleurBordure,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 4. Compteur de groupes trouvés
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${groupesFiltres.length} groupe(s) ouvert(s) à la participation",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Liste des cartes de groupes
              if (groupesFiltres.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        "Aucun groupe d'achat ne correspond à vos filtres.",
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final groupe = groupesFiltres[index];
                        final bool isFav = favorisIds.contains(groupe.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: couleurCarte,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: couleurBordure, width: 1.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: estSombre ? 0.25 : 0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // En-tête Grossiste avec badge vérifié
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
                                      child: const Icon(
                                        Icons.person_pin,
                                        size: 20,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  groupe.grossisteNom,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: couleurTexte,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified, size: 14, color: Color(0xFF1E88E5)),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Origine : ",
                                                style: TextStyle(fontSize: 11.5, color: couleurAttenue),
                                              ),
                                              DrapeauBadge(pays: groupe.paysOrigine, compact: true),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isFav ? Icons.favorite : Icons.favorite_border,
                                        color: isFav ? Colors.redAccent : couleurAttenue,
                                      ),
                                      onPressed: () => FavorisService.instance.toggleFavori(groupe, context),
                                    ),
                                  ],
                                ),
                              ),

                              Divider(height: 1, color: couleurBordure),

                              // Détail produit (Image + Titre + Prix)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.asset(
                                        groupe.imagePath,
                                        width: 88,
                                        height: 88,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 88,
                                          height: 88,
                                          color: couleurSurfaceDouce,
                                          child: Icon(Icons.image_not_supported, color: couleurAttenue),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            groupe.titre,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: couleurTexte,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            groupe.sousTitre,
                                            style: TextStyle(fontSize: 11.5, color: couleurAttenue),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),

                                          // Prix de gros vs Prix public
                                          Row(
                                            children: [
                                              Text(
                                                "${groupe.prixGroupe} FCFA",
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                              if (groupe.aPrixPublic) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                "${groupe.prixPublic} F",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  decoration: TextDecoration.lineThrough,
                                                  color: couleurAttenue,
                                                ),
                                                ),
                                              ],
                                              if (groupe.aPrixPublic) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: estSombre ? AppTheme.darkOliveSurface : const Color(0xFFE8F5E9),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  "-${groupe.pourcentageEconomie}%",
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppTheme.couleurSucces(context),
                                                  ),
                                                ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Jauge d'avancement du groupe (quantité confirmée / objectif)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Remplissage : ${groupe.quantiteActuelle} / ${groupe.quantiteObjectif} pièces",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: couleurTexte,
                                          ),
                                        ),
                                        Text(
                                          "${(groupe.ratio * 100).round()}%",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: groupe.ratio,
                                        minHeight: 8,
                                        backgroundColor: couleurSurfaceDouce,
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Encore ${groupe.reste} pièces pour expédition",
                                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                        ),
                                        Text(
                                          groupe.tempsRestant,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Courtier logistique & Boutons d'action
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Row(
                                  children: [
                                    // Fiche détaillée
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => FicheCampagneScreen.depuis(groupe),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: couleurTexte,
                                        side: BorderSide(color: couleurBordure),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      ),
                                      child: const Text("Détails", style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 10),

                                    // Bouton Rejoindre directement
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => FicheCampagneScreen.depuis(groupe),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.group_add, size: 18),
                                        label: const Text("Participer au Groupe"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: groupesFiltres.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showRechercheReferenceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.link, color: AppTheme.primary),
            SizedBox(width: 8),
            Text("Rechercher un Groupe"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Saisissez la référence du groupe ou collez le lien partagé par le grossiste :",
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Ex : DOG-882 ou lien...",
                filled: true,
                fillColor: const Color(0xFFFAF7F4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2D6CB)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final ref = controller.text.trim();
              Navigator.pop(ctx);
              if (ref.isNotEmpty) {
                setState(() => _searchQuery = ref);
              }
            },
            child: const Text("Filtrer"),
          ),
        ],
      ),
    );
  }
}
