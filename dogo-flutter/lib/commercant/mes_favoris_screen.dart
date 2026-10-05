import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'campagne_model.dart';
import 'favoris_service.dart';
import 'fiche_campagne_screen.dart';

/// Écran dédié « Mes Groupes Favoris » pour le Commerçant
/// Permet de suivre l'évolution des groupes mis en favoris et de les retirer à tout moment.
class MesFavorisScreen extends StatelessWidget {
  const MesFavorisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Mes Groupes Favoris",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: FavorisService.instance.favorisNotifier,
        builder: (context, favorisIds, _) {
          final groupesFavoris = FavorisService.instance.getGroupesFavoris();

          if (groupesFavoris.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        size: 46,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Aucun groupe en favori",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Ajoutez des groupes pour suivre leur progression.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        "Explorer les opportunités",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupesFavoris.length,
            itemBuilder: (context, index) {
              final groupe = groupesFavoris[index];
              return _buildCarteFavori(context, groupe);
            },
          );
        },
      ),
    );
  }

  Widget _buildCarteFavori(BuildContext context, GroupeCampagneModel groupe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A46321E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vignette produit
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 75,
                  height: 75,
                  color: const Color(0xFFF7F2EB),
                  child: Image.asset(
                    groupe.imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Détails
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            groupe.tempsRestant,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF996B00),
                            ),
                          ),
                        ),
                        // Bouton Supprimer des favoris
                        IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 22),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: "Retirer des favoris",
                          onPressed: () {
                            FavorisService.instance.toggleFavori(groupe, context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      groupe.titre,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      groupe.sousTitre,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          "${groupe.prixGroupe} FCFA",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${groupe.prixPublic} FCFA",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1EAE2)),
          const SizedBox(height: 8),

          // Jauge de progression
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Progression du lot : ${groupe.quantiteActuelle}/${groupe.quantiteObjectif}",
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
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: groupe.ratio,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1EAE2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),

          const SizedBox(height: 12),

          // Bouton Rejoindre
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FicheCampagneScreen(
                    titre: groupe.titre,
                    sousTitre: groupe.sousTitre,
                    imagePath: groupe.imagePath,
                    prixGroupe: groupe.prixGroupe,
                    prixPublic: groupe.prixPublic,
                    quantiteActuelle: groupe.quantiteActuelle,
                    quantiteObjectif: groupe.quantiteObjectif,
                    paysOrigine: groupe.paysOrigine,
                    courtierNom: groupe.courtierNom,
                    tempsRestant: groupe.tempsRestant,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Participer au groupe d'achat",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
