import 'package:flutter/foundation.dart';
import '../models/campagne_model.dart';
import '../models/participation_model.dart';
import '../models/remboursement_model.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';

/// Service gérant les Groupes d'achat / Campagnes via l'API Backend DoGo
class GroupeApiService {
  GroupeApiService._();
  static final GroupeApiService instance = GroupeApiService._();

  /// Liste vide par défaut (aucune fausse donnée)
  static final List<GroupeCampagneModel> campagnesRepli = [];

  /// Récupère la liste des groupes d'achat ouverts (GET /api/groupes)
  Future<List<GroupeCampagneModel>> explorer({
    String? recherche,
    int? categorieId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (recherche != null && recherche.trim().isNotEmpty) {
        queryParams['q'] = recherche.trim();
      }
      if (categorieId != null) {
        queryParams['categorieId'] = categorieId;
      }

      final response = await ApiClient.instance.get(
        ApiConfig.groupes,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response is List) {
        return response
            .map((item) => GroupeCampagneModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('GroupeApiService.explorer - Erreur API : $e');
      return [];
    }
  }

  /// Récupère les détails d'un groupe spécifique (GET /api/groupes/{id})
  Future<GroupeCampagneModel> detail(dynamic id) async {
    final response = await ApiClient.instance.get(ApiConfig.groupeDetail(id));
    if (response is Map<String, dynamic>) {
      return GroupeCampagneModel.fromJson(response);
    }
    throw Exception('Groupe d\'achat introuvable');
  }

  /// Rejoindre un groupe d'achat (POST /api/groupes/{groupeId}/participations)
  Future<Map<String, dynamic>> rejoindreGroupe({
    required dynamic groupeId,
    required int varianteId,
    required int quantite,
  }) async {
    final response = await ApiClient.instance.post(
      ApiConfig.rejoindreGroupe(groupeId),
      body: {
        'varianteId': varianteId,
        'quantite': quantite,
      },
    );

    if (response is! Map<String, dynamic> || response['id'] is! num) {
      throw const ApiException(statusCode: 0, message: 'Réservation non confirmée par le serveur Karavan.');
    }
    return response;
  }

  /// Récupère la liste des participations du commerçant connecté (GET /api/moi/participations)
  Future<List<ParticipationModel>> mesParticipations() async {
    try {
      final response = await ApiClient.instance.get(ApiConfig.mesParticipations);
      if (response is List) {
        return response
            .map((item) => ParticipationModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('GroupeApiService.mesParticipations - Erreur API : $e');
      return [];
    }
  }

  /// Annule une participation active (POST /api/participations/{id}/annulation, RG-31)
  /// Déclenche la libération du quota et le remboursement intégral des fonds en séquestre.
  Future<ParticipationModel> annulerParticipation(dynamic participationId) async {
    final response = await ApiClient.instance.post(
      ApiConfig.annulerParticipation(participationId),
    );
    if (response is Map) {
      return ParticipationModel.fromJson(Map<String, dynamic>.from(response));
    }
    throw Exception('Erreur lors de l\'annulation de la participation');
  }

  /// Récupère l'historique et l'état des demandes de remboursement du commerçant (GET /api/moi/remboursements)
  Future<List<RemboursementModel>> mesRemboursements() async {
    try {
      final response = await ApiClient.instance.get(ApiConfig.mesRemboursements);
      if (response is List) {
        return response
            .map((item) => RemboursementModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('GroupeApiService.mesRemboursements - Erreur API : $e');
      return [];
    }
  }

  // ---------------------------------------------------------------- gestion des groupes (courtier / grossiste)

  /// Catalogue des produits des grossistes actifs, pour monter un groupe (courtier, RG-16)
  Future<List<Map<String, dynamic>>> produitsDisponibles() async =>
      _liste(await ApiClient.instance.get('/api/catalogue/produits-disponibles'));

  /// Crée un groupe en brouillon (courtier, ou grossiste sur ses propres produits).
  /// Les montants sont des coûts unitaires en FCFA.
  Future<GroupeResume> creer({
    String? titre,
    required int produitId,
    required int quantiteCible,
    required DateTime dateLimite,
    required num marchandise,
    required num transport,
    required num douane,
    required num autres,
    int? delaiLivraisonJours,
    String? politiqueAnnulation,
    int? quantiteMinParCommercant,
  }) async {
    final response = await ApiClient.instance.post(ApiConfig.groupes, body: {
      if (titre != null && titre.trim().isNotEmpty) 'titre': titre.trim(),
      'produitId': produitId,
      'quantiteCible': quantiteCible,
      'dateLimite': dateLimite.toUtc().toIso8601String(),
      'marchandise': marchandise,
      'transport': transport,
      'douane': douane,
      'autres': autres,
      if (delaiLivraisonJours != null) 'delaiLivraisonJours': delaiLivraisonJours,
      if (politiqueAnnulation != null && politiqueAnnulation.isNotEmpty) 'politiqueAnnulation': politiqueAnnulation,
      if (quantiteMinParCommercant != null) 'quantiteMinParCommercant': quantiteMinParCommercant,
    });
    return GroupeResume.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// BROUILLON → EN_VALIDATION : le grossiste doit confirmer son stock (RG-18).
  /// Pour un groupe porté par le grossiste, la soumission vaut confirmation : il attend directement la publication.
  Future<GroupeResume> soumettre(int groupeId) async => GroupeResume.fromJson(
      Map<String, dynamic>.from(await ApiClient.instance.post('/api/groupes/$groupeId/soumission') as Map));

  /// Groupes créés par le courtier connecté
  Future<List<GroupeResume>> mesGroupesCourtier() async =>
      _liste(await ApiClient.instance.get(ApiConfig.mesGroupes)).map(GroupeResume.fromJson).toList();

  /// Tous les groupes montés sur les produits du grossiste connecté
  Future<List<GroupeResume>> groupesDuGrossiste() async =>
      _liste(await ApiClient.instance.get('/api/groupes/du-grossiste')).map(GroupeResume.fromJson).toList();

  /// Le grossiste confirme la disponibilité du stock (RG-18)
  Future<GroupeResume> validerDisponibilite(int groupeId) async => GroupeResume.fromJson(
      Map<String, dynamic>.from(await ApiClient.instance.post('/api/groupes/$groupeId/disponibilite') as Map));

  /// Le grossiste qui achemine lui-même son groupe signale une étape (départ, transit, douane, arrivée…)
  /// aux administrateurs, qui mettent à jour le suivi vu par les commerçants.
  Future<void> signalerEtape(int groupeId, {required String etape, String? commentaire}) =>
      ApiClient.instance.post('/api/groupes/$groupeId/etapes', body: {
        'etape': etape,
        if (commentaire != null && commentaire.trim().isNotEmpty) 'commentaire': commentaire.trim(),
      });

  /// Le grossiste signale un incident ou un problème logistique urgent à l'administrateur
  Future<void> signalerIncident(
    int groupeId, {
    required String motif,
    String? detail,
    String? pieceJointeUrl,
  }) =>
      ApiClient.instance.post('/api/groupes/$groupeId/incident', body: {
        'motif': motif,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
        if (pieceJointeUrl != null && pieceJointeUrl.trim().isNotEmpty) 'pieceJointeUrl': pieceJointeUrl.trim(),
      });

  /// Étapes déjà signalées par le grossiste (suivi du colis), de la plus ancienne à la plus récente
  Future<List<Map<String, dynamic>>> etapes(int groupeId) async =>
      _liste(await ApiClient.instance.get('/api/groupes/$groupeId/etapes'));

  /// Convois (suivi officiel mis à jour par dɔgɔ) des groupes visibles par l'utilisateur connecté
  Future<List<Map<String, dynamic>>> convois() async => _liste(await ApiClient.instance.get('/api/convois'));

  /// Commandes nées d'un groupe (ou réservations si en cours)
  Future<List<Map<String, dynamic>>> commandesDuGroupe(int groupeId) async =>
      _liste(await ApiClient.instance.get('/api/groupes/$groupeId/commandes'));

  /// Notifier les participants/acheteurs d'un groupe
  Future<void> notifierGroupe(int groupeId, String message) async {
    await ApiClient.instance.post(
      '/api/groupes/$groupeId/notifier',
      body: {'message': message},
    );
  }

  static List<Map<String, dynamic>> _liste(dynamic response) =>
      response is List ? response.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
}

/// Vue d'un groupe pour le courtier et le grossiste (GroupeVue du backend)
class GroupeResume {
  final int id;

  /// Titre donné par le créateur (le backend renvoie le nom du produit à défaut)
  final String titre;
  final String statut;
  final String produitNom;
  final int produitId;
  final String? photoUrl;
  final String courtierNom;
  final String grossisteNom;
  final int quantiteCible;
  final int quantiteReservee;
  final int quantiteConfirmee;
  final num prixUnitaire;
  final DateTime? dateOuverture;
  final DateTime? dateLimite;
  final bool disponibiliteValidee;

  /// Groupe monté par le grossiste lui-même, sans courtier : il en assure l'acheminement
  final bool porteParGrossiste;

  const GroupeResume({
    required this.id,
    this.titre = '',
    required this.statut,
    required this.produitNom,
    this.produitId = 0,
    this.photoUrl,
    this.courtierNom = '',
    this.grossisteNom = '',
    required this.quantiteCible,
    this.quantiteReservee = 0,
    this.quantiteConfirmee = 0,
    this.prixUnitaire = 0,
    this.dateOuverture,
    this.dateLimite,
    this.disponibiliteValidee = false,
    this.porteParGrossiste = false,
  });

  factory GroupeResume.fromJson(Map<String, dynamic> json) {
    final produit = (json['produit'] as Map?) ?? const {};
    int entier(Object? v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return GroupeResume(
      id: entier(json['id']),
      titre: json['titre']?.toString() ?? produit['nom']?.toString() ?? '',
      statut: json['statut']?.toString() ?? '',
      produitNom: produit['nom']?.toString() ?? 'Produit',
      produitId: entier(produit['id']),
      photoUrl: produit['photoUrl']?.toString(),
      courtierNom: ((json['courtier'] as Map?)?['nom'])?.toString() ?? '',
      grossisteNom: ((json['grossiste'] as Map?)?['nom'])?.toString() ?? '',
      quantiteCible: entier(json['quantiteCible']),
      quantiteReservee: entier(json['quantiteReservee']),
      quantiteConfirmee: entier(json['quantiteConfirmee']),
      prixUnitaire: (json['prixUnitaire'] as num?) ?? num.tryParse(json['prixUnitaire']?.toString() ?? '') ?? 0,
      dateOuverture: DateTime.tryParse(json['dateOuverture']?.toString() ?? ''),
      dateLimite: DateTime.tryParse(json['dateLimite']?.toString() ?? ''),
      disponibiliteValidee: json['disponibiliteValidee'] == true,
      porteParGrossiste: json['porteParGrossiste'] == true,
    );
  }

  /// Total des pièces engagées par les commerçants (réservations en cours + confirmations payées)
  int get quantiteEngagee => quantiteConfirmee + quantiteReservee;

  /// Quantité effective pour la jauge et l'affichage (si statut terminal/atteint, vaut au moins quantiteCible)
  int get quantiteProgression {
    if (const ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE', 'TERMINE'].contains(statut)) {
      return quantiteCible > 0 ? (quantiteEngagee >= quantiteCible ? quantiteEngagee : quantiteCible) : quantiteEngagee;
    }
    return quantiteEngagee;
  }

  /// Ratio réel de 0.0 à 1.0 pour la barre de progression
  double get ratioProgression {
    final cible = quantiteCible > 0 ? quantiteCible : 1;
    if (const ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE', 'TERMINE'].contains(statut)) {
      return 1.0;
    }
    return (quantiteEngagee / cible).clamp(0.0, 1.0);
  }

  /// Pourcentage de progression de 0 à 100%
  int get pourcentageProgression => (ratioProgression * 100).round();

  /// Indique si l'objectif est atteint à 100%
  bool get aAtteint100 =>
      ratioProgression >= 1.0 ||
      const ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE', 'TERMINE'].contains(statut);

  /// Le grossiste peut signaler les étapes d'acheminement une fois l'objectif atteint (100%)
  bool get acheminementAuGrossiste =>
      porteParGrossiste && aAtteint100 && const ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE', 'TERMINE'].contains(statut);

  /// Libellé lisible du statut (StatutGroupe côté backend)
  String get libelleStatut => switch (statut) {
        'BROUILLON' => 'Brouillon',
        'EN_VALIDATION' => disponibiliteValidee ? 'Attente publication' : 'Stock à confirmer',
        'OUVERT' => 'Ouvert aux commerçants',
        'OBJECTIF_ATTEINT' => 'Objectif atteint',
        'EN_EXPEDITION' => 'En expédition',
        'LIVRE' => 'Livré',
        'TERMINE' => 'Terminé',
        'ANNULE' => 'Annulé',
        'ECHOUE' => 'Échoué',
        _ => statut,
      };
}
