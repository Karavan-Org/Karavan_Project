import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groupe_api_service.dart';
import 'campagne_model.dart';

/// Service centralisé de gestion des Favoris et des Campagnes pour le Commerçant
/// Sans données de test factices : alimenté par l'API Backend Karavan.
class FavorisService {
  FavorisService._internal();
  static final FavorisService instance = FavorisService._internal();

  /// Catalogue dynamique alimenté par l'API Backend Karavan (initialement vide)
  late final ValueNotifier<List<GroupeCampagneModel>> campagnesNotifier =
      ValueNotifier<List<GroupeCampagneModel>>([]);

  List<GroupeCampagneModel> get toutesLesCampagnes => campagnesNotifier.value;

  Future<void> actualiserDepuisBackend() async {
    try {
      final groupes = await GroupeApiService.instance.explorer();
      campagnesNotifier.value = groupes;
    } catch (_) {}
  }

  // Set des favoris utilisateur (initialement vide)
  final ValueNotifier<Set<String>> favorisNotifier = ValueNotifier<Set<String>>({});

  bool estFavori(String id) {
    return favorisNotifier.value.contains(id);
  }

  void toggleFavori(GroupeCampagneModel groupe, BuildContext context) {
    final newSet = Set<String>.from(favorisNotifier.value);
    final wasFavori = newSet.contains(groupe.id);

    if (wasFavori) {
      newSet.remove(groupe.id);
    } else {
      newSet.add(groupe.id);
    }

    favorisNotifier.value = newSet;

    // Feedback visuel à l'utilisateur
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              wasFavori ? Icons.heart_broken_outlined : Icons.favorite,
              color: wasFavori ? Colors.white70 : AppTheme.danger,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                wasFavori
                    ? "« ${groupe.titre} » retiré des favoris"
                    : "« ${groupe.titre} » ajouté à vos favoris",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: wasFavori ? AppTheme.textPrimary : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  void retirerFavoriParId(String id, BuildContext context) {
    final list = campagnesNotifier.value;
    final groupe = list.firstWhere(
      (g) => g.id == id,
      orElse: () => GroupeCampagneModel(
        id: id,
        titre: "Article",
        sousTitre: "",
        imagePath: "assets/images/logo_karavan.png",
        prixGroupe: 0,
        prixPublic: 0,
        quantiteActuelle: 0,
        quantiteObjectif: 0,
        categorie: "",
      ),
    );
    toggleFavori(groupe, context);
  }

  List<GroupeCampagneModel> getGroupesFavoris() {
    return campagnesNotifier.value
        .where((g) => favorisNotifier.value.contains(g.id))
        .toList();
  }
}
