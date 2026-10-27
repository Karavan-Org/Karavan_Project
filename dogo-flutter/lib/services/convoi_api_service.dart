import 'api/api_client.dart';

/// Événement du suivi d'un convoi (EvenementVue du backend)
class EvenementConvoi {
  final int id;
  final String statut;
  final String localisation;
  final DateTime? date;

  const EvenementConvoi({required this.id, required this.statut, required this.localisation, this.date});

  factory EvenementConvoi.fromJson(Map<String, dynamic> j) => EvenementConvoi(
        id: (j['id'] as num?)?.toInt() ?? 0,
        statut: j['statut']?.toString() ?? '',
        localisation: j['localisation']?.toString() ?? '',
        date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
      );

  /// Libellé lisible : les étapes officielles ont un nom, les événements libres gardent leur texte
  String get libelle => switch (statut) {
        'CREATION_CONVOI' => "Convoi ouvert",
        'CHEZ_TRANSITAIRE' => "Remis au transitaire",
        'EN_TRANSIT' => "En transit",
        'BLOQUE_DOUANE' => "Contrôle douanier",
        'ARRIVE' => "Arrivé à destination",
        _ => statut,
      };
}

/// Convoi (expédition) d'un groupe d'achat (ConvoiVue du backend).
/// Machine d'états du serveur : ACHETE → CHEZ_TRANSITAIRE → EN_TRANSIT (⇄ BLOQUE_DOUANE) → ARRIVE.
class Convoi {
  final int id;
  final int groupeId;
  final String reference;
  final String statut;
  final DateTime? dateDepart;
  final String? transporteur;
  final List<EvenementConvoi> evenements;

  const Convoi({
    required this.id,
    required this.groupeId,
    required this.reference,
    required this.statut,
    this.dateDepart,
    this.transporteur,
    this.evenements = const [],
  });

  factory Convoi.fromJson(Map<String, dynamic> j) => Convoi(
        id: (j['id'] as num).toInt(),
        groupeId: (j['groupeId'] as num?)?.toInt() ?? 0,
        reference: j['reference']?.toString() ?? '',
        statut: j['statut']?.toString() ?? 'ACHETE',
        dateDepart: DateTime.tryParse(j['dateDepart']?.toString() ?? '')?.toLocal(),
        transporteur: j['transporteur']?.toString(),
        evenements: ((j['evenements'] as List?) ?? const [])
            .map((e) => EvenementConvoi.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static const etapes = ['ACHETE', 'CHEZ_TRANSITAIRE', 'EN_TRANSIT', 'ARRIVE'];

  /// Rang dans le parcours (le contrôle douanier est une pause de la phase de transit)
  int get rang => statut == 'BLOQUE_DOUANE' ? 2 : etapes.indexOf(statut).clamp(0, etapes.length - 1);

  bool get estArrive => statut == 'ARRIVE';

  String get libelleStatut => switch (statut) {
        'ACHETE' => "Ouvert — chez le grossiste",
        'CHEZ_TRANSITAIRE' => "Remis au transitaire",
        'EN_TRANSIT' => "En transit",
        'BLOQUE_DOUANE' => "Contrôle douanier",
        'ARRIVE' => "Arrivé à destination",
        _ => statut,
      };

  EvenementConvoi? get dernierEvenement => evenements.isEmpty ? null : evenements.last;
}

/// Appels /api/convois : lecture pour tous les acteurs concernés, actions réservées au courtier responsable.
class ConvoiApiService {
  ConvoiApiService._();
  static final ConvoiApiService instance = ConvoiApiService._();

  Future<List<Convoi>> lister() async {
    final rep = await ApiClient.instance.get('/api/convois');
    if (rep is! List) return [];
    return rep.map((e) => Convoi.fromJson(Map<String, dynamic>.from(e as Map))).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<Convoi> creer({required int groupeId, required String reference, String? transporteur}) async =>
      _convoi(await ApiClient.instance.post('/api/convois', body: {
        'groupeId': groupeId,
        'reference': reference,
        if (transporteur != null && transporteur.trim().isNotEmpty) 'transporteur': transporteur.trim(),
      }));

  Future<Convoi> remettreAuTransitaire(int id, {String? localisation}) async =>
      _convoi(await ApiClient.instance.post('/api/convois/$id/transitaire', body: _lieu(localisation)));

  /// Départ en transit, ou reprise après un contrôle douanier
  Future<Convoi> lancerTransit(int id) async => _convoi(await ApiClient.instance.post('/api/convois/$id/transit'));

  Future<Convoi> declarerDouane(int id, {String? localisation}) async =>
      _convoi(await ApiClient.instance.post('/api/convois/$id/douane', body: _lieu(localisation)));

  Future<Convoi> marquerArrive(int id, {String? localisation}) async =>
      _convoi(await ApiClient.instance.post('/api/convois/$id/arrivee', body: _lieu(localisation)));

  /// Point de passage libre (escale, entrepôt…), notifié aux commerçants du groupe
  Future<Convoi> ajouterEvenement(int id, {required String statut, required String localisation}) async =>
      _convoi(await ApiClient.instance
          .post('/api/convois/$id/evenements', body: {'statut': statut, 'localisation': localisation}));

  static Map<String, dynamic>? _lieu(String? localisation) =>
      localisation == null || localisation.trim().isEmpty ? null : {'localisation': localisation.trim()};

  static Convoi _convoi(dynamic rep) => Convoi.fromJson(Map<String, dynamic>.from(rep as Map));
}
