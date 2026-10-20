import 'package:flutter/material.dart';
import 'campagne_model.dart';
import 'favoris_service.dart';

/// Service centralisé de gestion du groupe actuellement sélectionné par le Commerçant.
/// Permet au Commerçant de sélectionner n'importe quel groupe affiché en arrière-plan,
/// puis d'appuyer sur (+) > REJOINDRE pour passer directement à l'écran de paiement séquestre.
class GroupeSelectionService {
  GroupeSelectionService._internal();
  static final GroupeSelectionService instance = GroupeSelectionService._internal();

  static const GroupeCampagneModel _repliDefaut = GroupeCampagneModel(
    id: "1",
    titre: "Sélectionnez un groupe",
    sousTitre: "",
    imagePath: "assets/images/logo_karavan.png",
    prixGroupe: 0,
    prixPublic: 0,
    quantiteActuelle: 0,
    quantiteObjectif: 1,
    categorie: "",
  );

  /// Le groupe actuellement sélectionné (initialisé avec le 1er groupe par défaut ou un repli)
  late final ValueNotifier<GroupeCampagneModel> selectionNotifier =
      ValueNotifier<GroupeCampagneModel>(
    FavorisService.instance.toutesLesCampagnes.isNotEmpty
        ? FavorisService.instance.toutesLesCampagnes.first
        : _repliDefaut,
  );

  GroupeCampagneModel get groupeSelectionne => selectionNotifier.value;

  void selectionner(GroupeCampagneModel groupe) {
    selectionNotifier.value = groupe;
  }

  bool estSelectionne(String id) {
    return selectionNotifier.value.id == id;
  }
}
