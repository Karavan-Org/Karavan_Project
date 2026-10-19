import '../widgets/image_produit.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'campagne_model.dart';
import '../services/auth_service.dart';
import '../services/api/api_config.dart';
import 'favoris_service.dart';
import 'mes_favoris_screen.dart';
import 'groupe_selection_service.dart';
import 'notifications_commercant_screen.dart';
import '../services/notification_api_service.dart';

/// Écran d'accueil principal du Commerçant
/// Vitrine d'achats groupés en cours avec mise en favoris, filtres et progression.
class CommercantHomeScreen extends StatefulWidget {
  const CommercantHomeScreen({super.key});

  @override
  State<CommercantHomeScreen> createState() => _CommercantHomeScreenState();
}

class _CommercantHomeScreenState extends State<CommercantHomeScreen> {
  String _categorieActive = "Tous";
  String _courtierActif = "Tous";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  int _nbNotifsNonLues = 0;

  final List<String> _categories = [
    "Tous",
    "Sneakers",
    "Mode Féminine",
    "Chaussures",
    "Montres & Bijoux",
  ];

  final List<String> _courtiers = [
    "Tous",
    "Touré Transit & Logistique SARL",
    "Diarra Logistique Express",
  ];

  @override
  void initState() {
    super.initState();
    FavorisService.instance.actualiserDepuisBackend();
    _chargerNotifsNonLues();
  }

  Future<void> _chargerNotifsNonLues() async {
    try {
      final nb = await NotificationApiService.instance.nombreNonLues();
      if (mounted) setState(() => _nbNotifsNonLues = nb);
    } catch (_) {}
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
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            FavorisService.instance.favorisNotifier,
            FavorisService.instance.campagnesNotifier,
          ]),
          builder: (context, _) {
            final favorisIds = FavorisService.instance.favorisNotifier.value;
            final toutesCampagnes = FavorisService.instance.toutesLesCampagnes;

            // Filtrage par catégorie, courtier, favoris et recherche
            final campagnesFiltrees = toutesCampagnes.where((c) {
              if (_categorieActive == "Favoris" && !favorisIds.contains(c.id)) {
                return false;
              }
              if (_categorieActive != "Tous" &&
                  _categorieActive != "Favoris" &&
                  c.categorie != _categorieActive) {
                return false;
              }
              if (_courtierActif != "Tous" && c.courtierNom != _courtierActif) {
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
              onRefresh: () async {
                await Future.wait([
                  FavorisService.instance.actualiserDepuisBackend(),
                  _chargerNotifsNonLues(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // 1. En-tête personnalisé Commerçant avec bouton Favoris & Notifications
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        ValueListenableBuilder<UtilisateurProfil?>(
                          valueListenable: AuthService.instance.profilNotifier,
                          builder: (context, user, _) {
                            final String initiales = (user?.nomComplet.isNotEmpty ?? false)
                                ? user!.nomComplet
                                    .split(' ')
                                    .take(2)
                                    .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                                    .join()
                                : "DG";

                            final bool aPhoto = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;
                            final String prenom = (user?.nomComplet.isNotEmpty ?? false)
                                ? user!.nomComplet.split(' ').first
                                : "Commerçant";
                            final String quartier = (user?.quartier?.isNotEmpty ?? false)
                                ? user!.quartier!
                                : ((user?.structure?.isNotEmpty ?? false)
                                    ? user!.structure!
                                    : "Bamako, Mali");

                            return Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                    backgroundImage: aPhoto
                                        ? NetworkImage(ApiConfig.resolutionImageUrl(user.photoUrl))
                                        : null,
                                    child: !aPhoto
                                        ? Text(
                                            initiales,
                                            style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Bonjour $prenom 👋",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 13, color: AppTheme.secondary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                quartier,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppTheme.textMuted,
                                                  fontWeight: FontWeight.w600,
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
                            );
                          },
                        ),

                        // Bouton d'accès direct à Mes Favoris avec Badge de compteur
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: favorisIds.isNotEmpty
                                  ? Colors.redAccent.withValues(alpha: 0.3)
                                  : const Color(0xFFE8E0D7),
                            ),
                          ),
                          child: Stack(
                            children: [
                              IconButton(
                                icon: Icon(
                                  favorisIds.isNotEmpty ? Icons.favorite : Icons.favorite_border,
                                  color: favorisIds.isNotEmpty
                                      ? Colors.redAccent
                                      : AppTheme.textPrimary,
                                  size: 22,
                                ),
                                tooltip: "Mes Favoris",
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const MesFavorisScreen()),
                                  );
                                },
                              ),
                              if (favorisIds.isNotEmpty)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      "${favorisIds.length}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Cloche de notifications avec Badge dynamique
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _nbNotifsNonLues > 0
                                  ? AppTheme.primary.withValues(alpha: 0.3)
                                  : const Color(0xFFE8E0D7),
                            ),
                          ),
                          child: Stack(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _nbNotifsNonLues > 0
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_none_rounded,
                                  color: _nbNotifsNonLues > 0
                                      ? AppTheme.primary
                                      : AppTheme.textPrimary,
                                  size: 22,
                                ),
                                tooltip: "Notifications",
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationsCommercantScreen(),
                                    ),
                                  );
                                  _chargerNotifsNonLues();
                                },
                              ),
                              if (_nbNotifsNonLues > 0)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE53935),
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      "$_nbNotifsNonLues",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Barre de recherche dynamique
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5DDD5)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          icon: const Icon(Icons.search, color: AppTheme.textMuted),
                          hintText: "Rechercher un produit, une marque, un groupe...",
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

                  // 3. Bannière Hero Achat Groupé International
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, Color(0xFF8C5F3F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A46321E),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "PRIX USINE DIRECT",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Rejoignez les groupes d'achat\net divisez vos coûts par 2 !",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Fret Chine 🇨🇳 & Turquie 🇹🇷 vers Bamako avec fonds sécurisés sous séquestre.",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Filtres de Catégories avec puce spéciale Favoris
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        // Puce spéciale « Favoris »
                        GestureDetector(
                          onTap: () => setState(() => _categorieActive = "Favoris"),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _categorieActive == "Favoris"
                                  ? Colors.redAccent
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _categorieActive == "Favoris"
                                    ? Colors.redAccent
                                    : const Color(0xFFE2D9D0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 14,
                                  color: _categorieActive == "Favoris"
                                      ? Colors.white
                                      : Colors.redAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Favoris (${favorisIds.length})",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _categorieActive == "Favoris"
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: _categorieActive == "Favoris"
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Autres catégories standards
                        ..._categories.map((cat) {
                          final isSelected = cat == _categorieActive;
                          return GestureDetector(
                            onTap: () => setState(() => _categorieActive = cat),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primary : const Color(0xFFE2D9D0),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // 4. bis - Filtre rapide par Courtier Organisateur
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          "Courtiers & Transitaires :",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: _courtiers.map((courtier) {
                        final isSelected = courtier == _courtierActif;
                        final label = courtier == "Tous" ? "Tous les courtiers" : courtier;
                        return GestureDetector(
                          onTap: () => setState(() => _courtierActif = courtier),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.secondary : const Color(0xFFF7F2EB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppTheme.secondary : const Color(0xFFE5DDD5),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (courtier != "Tous") ...[
                                  Icon(
                                    Icons.business,
                                    size: 13,
                                    color: isSelected ? Colors.white : AppTheme.primary,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Section "Groupes d'Achat en cours"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _categorieActive == "Favoris"
                              ? "Mes Groupes Favoris (${campagnesFiltrees.length})"
                              : "Groupes bientôt clôturés 🔥",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (_categorieActive != "Favoris")
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MesFavorisScreen()),
                              );
                            },
                            child: const Text(
                              "Mes favoris",
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Si aucun résultat après filtrage
                  if (campagnesFiltrees.isEmpty)
                    Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.favorite_border, size: 40, color: AppTheme.textMuted),
                            const SizedBox(height: 10),
                            Text(
                              _categorieActive == "Favoris"
                                  ? "Vous n'avez pas encore de groupe en favoris."
                                  : "Aucun groupe d'achat trouvé pour ce critère.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Bannière interactive du groupe sélectionné pour le bouton (+) REJOINDRE
                    ValueListenableBuilder<GroupeCampagneModel>(
                      valueListenable: GroupeSelectionService.instance.selectionNotifier,
                      builder: (context, selection, _) {
                        return Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                    children: [
                                      const TextSpan(text: "Groupe sélectionné : "),
                                      TextSpan(
                                        text: selection.titre,
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary),
                                      ),
                                      TextSpan(
                                        text: " (${selection.prixGroupe} F) • Appuyez sur (+) > Rejoindre pour payer 💳",
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Liste horizontale des groupes avec sélection réactive
                    SizedBox(
                      height: 360,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: campagnesFiltrees.length,
                        itemBuilder: (context, index) {
                          final groupe = campagnesFiltrees[index];
                          final isFav = favorisIds.contains(groupe.id);
                          return _buildCarteCampagne(context, groupe, isFav);
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 6. Section "Opportunités d'importation directes"
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Opportunités d'importation directes",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: toutesCampagnes.skip(2).map((groupe) {
                          final isFav = favorisIds.contains(groupe.id);
                          return _buildCarteVerticale(context, groupe, isFav);
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildCarteCampagne(
    BuildContext context,
    GroupeCampagneModel groupe,
    bool isFavori,
  ) {
    return ValueListenableBuilder<GroupeCampagneModel>(
      valueListenable: GroupeSelectionService.instance.selectionNotifier,
      builder: (context, selection, _) {
        final bool isSelected = (selection.id == groupe.id);

        return GestureDetector(
          onTap: () {
            GroupeSelectionService.instance.selectionner(groupe);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.primary,
                duration: const Duration(seconds: 2),
                content: Text(
                  "'${groupe.titre}' sélectionné\n(+) > REJOINDRE pour payer",
                ),
              ),
            );
          },
          child: Container(
            width: 230,
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFDFBF8) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primary : const Color(0xFFEFE8E1),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.20) : const Color(0x0A46321E),
                  blurRadius: isSelected ? 18 : 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vignette image avec boutons flottants (badge temps & favori & sélection)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 125,
                        width: double.infinity,
                        color: const Color(0xFFF7F2EB),
                        child: imageProduit(
                          groupe.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shopping_bag_outlined,
                            size: 50,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    // Badge temps restant
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          groupe.tempsRestant,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    // Bouton Favori flottant sur l'image
                    Positioned(
                      top: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: () {
                          FavorisService.instance.toggleFavori(groupe, context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Color(0x22000000), blurRadius: 4),
                            ],
                          ),
                          child: Icon(
                            isFavori ? Icons.favorite : Icons.favorite_border,
                            color: isFavori ? Colors.redAccent : AppTheme.textMuted,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    // Badge de sélection dynamique
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 12,
                              color: isSelected ? Colors.white : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSelected ? "Sélectionné" : "Choisir",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Titre & Sous-titre
                Text(
                  groupe.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  groupe.sousTitre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 5),

                // Badge Courtier certifié
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2EB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE5DDD5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 11, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "Courtier : ${groupe.courtierNom}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Prix
                Row(
                  children: [
                    Text(
                      "${groupe.prixGroupe} F",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${groupe.prixPublic} F",
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Jauge de progression
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${groupe.quantiteActuelle}/${groupe.quantiteObjectif} réservés",
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "${(groupe.ratio * 100).toInt()}%",
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: groupe.ratio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1EAE2),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCarteVerticale(
    BuildContext context,
    GroupeCampagneModel groupe,
    bool isFavori,
  ) {
    return ValueListenableBuilder<GroupeCampagneModel>(
      valueListenable: GroupeSelectionService.instance.selectionNotifier,
      builder: (context, selection, _) {
        final bool isSelected = (selection.id == groupe.id);

        return GestureDetector(
          onTap: () {
            GroupeSelectionService.instance.selectionner(groupe);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.primary,
                duration: const Duration(seconds: 2),
                content: Text(
                  "'${groupe.titre}' sélectionné\n(+) > REJOINDRE pour payer",
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFDFBF8) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primary : const Color(0xFFEFE8E1),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.16) : const Color(0x0846321E),
                  blurRadius: isSelected ? 16 : 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 75,
                    height: 75,
                    color: const Color(0xFFF7F2EB),
                    child: imageProduit(
                      groupe.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined),
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
                              groupe.titre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : const Color(0xFFF0EAE3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 11,
                                  color: isSelected ? Colors.white : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isSelected ? "Sélectionné" : "Choisir",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        groupe.sousTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.verified, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "Posté par : ${groupe.courtierNom}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            "${groupe.prixGroupe} FCFA",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${groupe.prixPublic} F",
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: groupe.ratio,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF1EAE2),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFavori ? Icons.favorite : Icons.favorite_border,
                    color: isFavori ? Colors.redAccent : AppTheme.textMuted,
                    size: 20,
                  ),
                  onPressed: () {
                    FavorisService.instance.toggleFavori(groupe, context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
