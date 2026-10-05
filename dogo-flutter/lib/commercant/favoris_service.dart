import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'campagne_model.dart';

/// Service centralisé de gestion des Favoris pour le Commerçant
/// Utilise ValueNotifier pour une réactivité instantanée à travers tous les écrans.
class FavorisService {
  FavorisService._internal();
  static final FavorisService instance = FavorisService._internal();

  // Catalogue central de démonstration basé sur les visuels officiels DoGo
  final List<GroupeCampagneModel> toutesLesCampagnes = const [
    GroupeCampagneModel(
      id: "grp-nike-joyride",
      titre: "Nike Joyride",
      sousTitre: "Lot export Turquie • 20 paires assorties",
      imagePath: "assets/images/Nike_Joyride.jpg",
      prixGroupe: 18500,
      prixPublic: 45000,
      quantiteActuelle: 16,
      quantiteObjectif: 20,
      categorie: "Sneakers",
      paysOrigine: "Istanbul, Turquie",
      courtierNom: "Touré Transit & Logistique SARL",
      grossisteNom: "Grossiste Cissé & Frères (Istanbul)",
      tempsRestant: "3 jours restants",
    ),
    GroupeCampagneModel(
      id: "grp-abaya-nida",
      titre: "Abaya Douceur Nida Purple",
      sousTitre: "Confection Dubaï • Lot de 15 pièces",
      imagePath: "assets/images/soft-elegance-abaya-coat-nida-purple-noor-and-grace.webp",
      prixGroupe: 22500,
      prixPublic: 55000,
      quantiteActuelle: 12,
      quantiteObjectif: 15,
      categorie: "Mode Féminine",
      paysOrigine: "Dubaï, Émirats Arabes Unis",
      courtierNom: "Touré Transit & Logistique SARL",
      grossisteNom: "Grossiste Dubaï Fashion Ltd",
      tempsRestant: "2 jours restants",
    ),
    GroupeCampagneModel(
      id: "grp-sandales-rouges",
      titre: "Sandales Talon Rouge Soirée",
      sousTitre: "Lot de 12 paires assorties (36-41)",
      imagePath: "assets/images/sandales-talon-rouge.jpg",
      prixGroupe: 12000,
      prixPublic: 28000,
      quantiteActuelle: 9,
      quantiteObjectif: 12,
      categorie: "Chaussures",
      paysOrigine: "Guangzhou, Chine",
      courtierNom: "Diarra Logistique Express",
      grossisteNom: "Grossiste Diallo Import Guangzhou",
      tempsRestant: "4 jours restants",
    ),
    GroupeCampagneModel(
      id: "grp-montre-homme-inox",
      titre: "Montre Quartz Homme Acier Inox",
      sousTitre: "Lot de 25 pièces • Cadran rond luxe",
      imagePath: "assets/images/Montre-Homme-Quartz-Acier-Inoxydable-Cadran-Rond-Affichage-Analogique-Et-Num-rique-Boucle-Pliante-Simple-Cristal-Renforc-Nihaojewelry-France.webp",
      prixGroupe: 7500,
      prixPublic: 20000,
      quantiteActuelle: 18,
      quantiteObjectif: 25,
      categorie: "Montres & Bijoux",
      paysOrigine: "Yiwu, Chine",
      courtierNom: "Touré Transit & Logistique SARL",
      grossisteNom: "Grossiste Yiwu Commerce International",
      tempsRestant: "5 jours restants",
    ),
    GroupeCampagneModel(
      id: "grp-bottines-cuir",
      titre: "Bottines en cuir noir de ville",
      sousTitre: "Lot de 10 paires • Qualité premium",
      imagePath: "assets/images/black-dress-boots-2-mob.jpg",
      prixGroupe: 24000,
      prixPublic: 58000,
      quantiteActuelle: 7,
      quantiteObjectif: 10,
      categorie: "Chaussures",
      paysOrigine: "Istanbul, Turquie",
      courtierNom: "Touré Transit & Logistique SARL",
      grossisteNom: "Grossiste Ozkan Leather Istanbul",
      tempsRestant: "6 jours restants",
    ),
  ];

  // Set des identifiants favoris avec un favori par défaut pour la démo
  final ValueNotifier<Set<String>> favorisNotifier = ValueNotifier<Set<String>>({
    "grp-nike-joyride",
  });

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
              color: wasFavori ? Colors.white70 : Colors.redAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                wasFavori
                    ? "« ${groupe.titre} » retiré des favoris"
                    : "« ${groupe.titre} » ajouté à vos favoris ❤️",
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
    final groupe = toutesLesCampagnes.firstWhere(
      (g) => g.id == id,
      orElse: () => toutesLesCampagnes.first,
    );
    toggleFavori(groupe, context);
  }

  List<GroupeCampagneModel> getGroupesFavoris() {
    return toutesLesCampagnes
        .where((g) => favorisNotifier.value.contains(g.id))
        .toList();
  }
}
