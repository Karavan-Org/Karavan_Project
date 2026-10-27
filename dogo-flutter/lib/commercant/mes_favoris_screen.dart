import '../widgets/image_produit.dart';
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
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        title: const Text(
          "Mes Groupes Favoris",
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.couleurCarte(context),
        elevation: 0,
        foregroundColor: AppTheme.couleurTexte(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          FavorisService.instance.favorisNotifier,
          FavorisService.instance.campagnesNotifier,
        ]),
        builder: (context, _) {
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
                        color: AppTheme.couleurSurfaceDouce(context),
                        shape: BoxShape.circle,
                      ),
                    child: Icon(
                        Icons.favorite_border,
                        size: 46,
                      color: AppTheme.couleurAccent(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Aucun groupe en favori",
                      style: TextStyle(fontFamily: AppTheme.policeTitre,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.couleurTexte(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ajoutez des groupes pour suivre leur progression.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context), height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.couleurAccent(context),
                        foregroundColor: AppTheme.texteSur(AppTheme.couleurAccent(context)),
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
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A2C241E),
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
                  color: AppTheme.couleurSurfaceDouce(context),
                  child: imageProduit(
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
                            color: AppTheme.estSombre(context) ? AppTheme.darkOcreSurface : AppTheme.ocreClair,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            groupe.tempsRestant,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.couleurAttention(context),
                            ),
                          ),
                        ),
                        // Bouton Supprimer des favoris
                        IconButton(
                          icon: Icon(Icons.favorite, color: AppTheme.couleurDanger(context), size: 22),
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
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.couleurTexte(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      groupe.sousTitre,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          "${groupe.prixGroupe} FCFA",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.couleurAccent(context),
                          ),
                        ),
                        if (groupe.prixPublic > groupe.prixGroupe) ...[
                          const SizedBox(width: 8),
                          Text(
                            "${groupe.prixPublic} FCFA",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.couleurTexteAttenue(context),
                              decoration: TextDecoration.lineThrough,
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

          const SizedBox(height: 12),
          Divider(color: AppTheme.couleurBordure(context)),
          const SizedBox(height: 8),

          // Jauge de progression
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Progression du lot : ${groupe.quantiteActuelle}/${groupe.quantiteObjectif}",
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.couleurTexte(context)),
              ),
              Text(
                "${(groupe.ratio * 100).toInt()}%",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurAccent(context),
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
              backgroundColor: AppTheme.couleurBordure(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.couleurSucces(context)),
            ),
          ),

          const SizedBox(height: 12),

          // Bouton Rejoindre
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FicheCampagneScreen(
                    id: groupe.id,
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
                    groupe: groupe,
                    variantes: groupe.variantes,
                    quantiteMin: groupe.quantiteMinParCommercant,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.couleurAccent(context),
              foregroundColor: AppTheme.texteSur(AppTheme.couleurAccent(context)),
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
