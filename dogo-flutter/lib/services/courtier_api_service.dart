import '../models/campagne_model.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

/// Produit d'un grossiste actif proposé au Courtier pour monter un groupe (contrat `ProduitDisponibleVue`)
class ProduitDisponible {
  final int id;
  final String nom;
  final String grossisteNom;
  final String paysOrigine;
  final List<VarianteGroupe> variantes;

  const ProduitDisponible({
    required this.id,
    required this.nom,
    this.grossisteNom = '',
    this.paysOrigine = '',
    this.variantes = const [],
  });

  factory ProduitDisponible.fromJson(Map<String, dynamic> json) => ProduitDisponible(
        id: (json['id'] as num).toInt(),
        nom: json['nom']?.toString() ?? '',
        grossisteNom: json['grossisteNom']?.toString() ?? '',
        paysOrigine: json['paysOrigine']?.toString() ?? '',
        variantes: (json['variantes'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(VarianteGroupe.fromJson)
            .toList(),
      );
}

/// Étape de suivi d'un convoi (contrat `EvenementVue`)
class EvenementConvoi {
  final String statut;
  final String localisation;
  final DateTime? date;

  const EvenementConvoi({required this.statut, required this.localisation, this.date});

  factory EvenementConvoi.fromJson(Map<String, dynamic> json) => EvenementConvoi(
        statut: json['statut']?.toString() ?? '',
        localisation: json['localisation']?.toString() ?? '',
        date: DateTime.tryParse(json['date']?.toString() ?? '')?.toLocal(),
      );
}

/// Convoi d'expédition (contrat `ConvoiVue`) : ACHETE → CHEZ_TRANSITAIRE → EN_TRANSIT ⇄ BLOQUE_DOUANE → ARRIVE
class Convoi {
  final int id;
  final int? groupeId;
  final String reference;
  final String statut;
  final String transporteur;
  final List<EvenementConvoi> evenements;

  const Convoi({
    required this.id,
    required this.reference,
    required this.statut,
    this.groupeId,
    this.transporteur = '',
    this.evenements = const [],
  });

  factory Convoi.fromJson(Map<String, dynamic> json) => Convoi(
        id: (json['id'] as num).toInt(),
        groupeId: (json['groupeId'] as num?)?.toInt(),
        reference: json['reference']?.toString() ?? '',
        statut: json['statut']?.toString() ?? '',
        transporteur: json['transporteur']?.toString() ?? '',
        evenements: (json['evenements'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EvenementConvoi.fromJson)
            .toList(),
      );
}

/// Point de retrait (contrat `PointVue`)
class PointRetrait {
  final int id;
  final String nom;
  final String adresse;
  final String quartier;

  const PointRetrait({required this.id, required this.nom, this.adresse = '', this.quartier = ''});

  factory PointRetrait.fromJson(Map<String, dynamic> json) => PointRetrait(
        id: (json['id'] as num).toInt(),
        nom: json['nom']?.toString() ?? '',
        adresse: json['adresse']?.toString() ?? '',
        quartier: json['quartier']?.toString() ?? '',
      );
}

/// Portefeuille des commissions du Courtier (contrat `PortefeuilleVue`)
class Portefeuille {
  final num soldeBloque;
  final num soldeDisponible;
  final String devise;

  const Portefeuille({required this.soldeBloque, required this.soldeDisponible, this.devise = 'XOF'});

  factory Portefeuille.fromJson(Map<String, dynamic> json) => Portefeuille(
        soldeBloque: json['soldeBloque'] as num? ?? 0,
        soldeDisponible: json['soldeDisponible'] as num? ?? 0,
        devise: json['devise']?.toString() ?? 'XOF',
      );
}

/// Mouvement du portefeuille (contrat `MouvementVue`)
class MouvementPortefeuille {
  final String type;
  final num montant;
  final DateTime? date;
  final String reference;

  const MouvementPortefeuille({required this.type, required this.montant, this.date, this.reference = ''});

  factory MouvementPortefeuille.fromJson(Map<String, dynamic> json) => MouvementPortefeuille(
        type: json['type']?.toString() ?? '',
        montant: json['montant'] as num? ?? 0,
        date: DateTime.tryParse(json['date']?.toString() ?? '')?.toLocal(),
        reference: json['reference']?.toString() ?? '',
      );
}

/// Service des actions Courtier : groupes d'achat (RG-16 à RG-20), acheminement (RG-50 à RG-53) et convois
class CourtierApiService {
  CourtierApiService._();
  static final CourtierApiService instance = CourtierApiService._();

  final ApiClient _api = ApiClient.instance;

  static List<Map<String, dynamic>> _liste(dynamic response) =>
      response is List ? response.whereType<Map<String, dynamic>>().toList() : const [];

  static Map<String, dynamic> _objet(dynamic response) {
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Format de réponse serveur inattendu');
    }
    return response;
  }

  // ------------------------------------------------------------------ groupes

  /// GET /api/groupes/mes-groupes
  Future<List<GroupeCampagneModel>> mesGroupes() async =>
      _liste(await _api.get(ApiConfig.mesGroupes)).map(GroupeCampagneModel.fromJson).toList();

  /// GET /api/catalogue/produits-disponibles
  Future<List<ProduitDisponible>> produitsDisponibles() async =>
      _liste(await _api.get(ApiConfig.produitsDisponibles)).map(ProduitDisponible.fromJson).toList();

  /// POST /api/groupes : crée un brouillon (montants unitaires en FCFA, RG-17)
  Future<GroupeCampagneModel> creerGroupe({
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
    final response = await _api.post(ApiConfig.groupes, body: {
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
    return GroupeCampagneModel.fromJson(_objet(response));
  }

  /// POST /api/groupes/{id}/soumission : BROUILLON → EN_VALIDATION
  Future<GroupeCampagneModel> soumettre(String groupeId) async =>
      GroupeCampagneModel.fromJson(_objet(await _api.post(ApiConfig.soumettreGroupe(groupeId))));

  /// POST /api/groupes/{id}/annulation
  Future<GroupeCampagneModel> annuler(String groupeId, String motif) async => GroupeCampagneModel.fromJson(
      _objet(await _api.post(ApiConfig.annulerGroupe(groupeId), body: {'motif': motif})));

  // -------------------------------------------------------------- acheminement

  /// GET /api/groupes/{id}/commandes
  Future<List<Map<String, dynamic>>> commandesDuGroupe(String groupeId) async =>
      _liste(await _api.get(ApiConfig.commandesDuGroupe(groupeId)));

  /// POST /api/groupes/{id}/preparation (groupe OBJECTIF_ATTEINT)
  Future<List<Map<String, dynamic>>> preparer(String groupeId) async =>
      _liste(await _api.post(ApiConfig.preparerGroupe(groupeId)));

  /// POST /api/groupes/{id}/expedition (toutes les commandes préparées)
  Future<List<Map<String, dynamic>>> expedier(String groupeId) async =>
      _liste(await _api.post(ApiConfig.expedierGroupe(groupeId)));

  /// POST /api/groupes/{id}/reception-point-retrait (groupe LIVRE) : génère les codes de retrait
  Future<List<Map<String, dynamic>>> confirmerArriveeAuPoint(String groupeId, int pointRetraitId) async =>
      _liste(await _api.post(ApiConfig.arriveePointRetrait(groupeId), body: {'pointRetraitId': pointRetraitId}));

  /// GET /api/points-retrait
  Future<List<PointRetrait>> pointsRetrait() async =>
      _liste(await _api.get(ApiConfig.pointsRetrait)).map(PointRetrait.fromJson).toList();

  // ------------------------------------------------------------------- convois

  /// GET /api/convois
  Future<List<Convoi>> convois() async => _liste(await _api.get(ApiConfig.convois)).map(Convoi.fromJson).toList();

  /// POST /api/convois
  Future<Convoi> creerConvoi({required int groupeId, required String reference, String? transporteur}) async =>
      Convoi.fromJson(_objet(await _api.post(ApiConfig.convois, body: {
        'groupeId': groupeId,
        'reference': reference,
        if (transporteur != null && transporteur.isNotEmpty) 'transporteur': transporteur,
      })));

  /// Fait avancer le convoi : `transitaire`, `transit`, `douane` ou `arrivee`
  Future<Convoi> avancerConvoi(int convoiId, String action, {String? localisation}) async => Convoi.fromJson(_objet(
      await _api.post(ApiConfig.convoiAction(convoiId, action),
          body: localisation != null && localisation.isNotEmpty ? {'localisation': localisation} : null)));

  // --------------------------------------------------------------- portefeuille

  /// GET /api/moi/portefeuille
  Future<Portefeuille> portefeuille() async => Portefeuille.fromJson(_objet(await _api.get(ApiConfig.portefeuille)));

  /// GET /api/moi/portefeuille/mouvements
  Future<List<MouvementPortefeuille>> mouvements() async =>
      _liste(await _api.get(ApiConfig.portefeuilleMouvements)).map(MouvementPortefeuille.fromJson).toList();

  /// POST /api/moi/portefeuille/retraits (Idempotency-Key obligatoire)
  Future<Portefeuille> retirer({required int montant, required int moyenPaiementId, required String cle}) async =>
      Portefeuille.fromJson(_objet(await _api.post(
        ApiConfig.portefeuilleRetraits,
        headers: {'Idempotency-Key': cle},
        body: {'montant': montant, 'moyenPaiementId': moyenPaiementId},
      )));

  /// POST /api/convois/{id}/evenements : jalon libre (statut + localisation)
  Future<Convoi> ajouterEtape(int convoiId, {required String statut, required String localisation}) async =>
      Convoi.fromJson(_objet(await _api.post(ApiConfig.convoiAction(convoiId, 'evenements'),
          body: {'statut': statut, 'localisation': localisation})));
}
