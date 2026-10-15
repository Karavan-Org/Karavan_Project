import 'api/api_client.dart';
import 'auth_service.dart';

class MoyenPaiementItem {
  final int id;
  final String numero;
  final String operateur; // ORANGE_MONEY, MOOV_MONEY, WAVE
  final bool parDefaut;

  const MoyenPaiementItem({
    required this.id,
    required this.numero,
    required this.operateur,
    required this.parDefaut,
  });

  factory MoyenPaiementItem.fromJson(Map<String, dynamic> json) {
    return MoyenPaiementItem(
      id: (json['id'] as num).toInt(),
      numero: json['numero'] as String? ?? '',
      operateur: json['operateur'] as String? ?? 'ORANGE_MONEY',
      parDefaut: json['parDefaut'] as bool? ?? false,
    );
  }
}

class ProfilDetails {
  final int id;
  final String type;
  final String nom;
  final String telephone;
  final String langue;
  final String statut;
  final Map<String, dynamic> details;

  const ProfilDetails({
    required this.id,
    required this.type,
    required this.nom,
    required this.telephone,
    required this.langue,
    required this.statut,
    this.details = const {},
  });

  factory ProfilDetails.fromJson(Map<String, dynamic> json) {
    return ProfilDetails(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      langue: json['langue'] as String? ?? 'fr',
      statut: json['statut'] as String? ?? '',
      details: (json['details'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class ProfilApiService {
  ProfilApiService._();
  static final ProfilApiService instance = ProfilApiService._();

  Future<ProfilDetails> monProfil() async {
    final rep = await ApiClient.instance.get('/api/moi');
    return ProfilDetails.fromJson(rep as Map<String, dynamic>);
  }

  Future<ProfilDetails> modifierProfil({String? nom, String? langue}) async {
    final rep = await ApiClient.instance.patch(
      '/api/moi',
      body: {
        if (nom != null) 'nom': nom,
        if (langue != null) 'langue': langue,
      },
    );
    final p = ProfilDetails.fromJson(rep as Map<String, dynamic>);
    final courant = AuthService.instance.profilActuel;
    if (courant != null) {
      AuthService.instance.profilNotifier.value = UtilisateurProfil(
        id: p.id,
        type: p.type,
        nom: p.nom,
        telephone: p.telephone,
        statut: p.statut,
        permissions: courant.permissions,
      );
    }
    return p;
  }

  Future<List<MoyenPaiementItem>> mesMoyensPaiement() async {
    final rep = await ApiClient.instance.get('/api/moi/moyens-paiement');
    if (rep is! List) return [];
    return rep.map((e) => MoyenPaiementItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MoyenPaiementItem> ajouterMoyenPaiement({
    required String numero,
    required String operateur,
    bool parDefaut = false,
  }) async {
    final rep = await ApiClient.instance.post(
      '/api/moi/moyens-paiement',
      body: {
        'numero': numero,
        'operateur': operateur,
        'parDefaut': parDefaut,
      },
    );
    return MoyenPaiementItem.fromJson(rep as Map<String, dynamic>);
  }

  Future<void> definirMoyenParDefaut(int id) async {
    await ApiClient.instance.put('/api/moi/moyens-paiement/$id/defaut');
  }

  Future<void> supprimerMoyenPaiement(int id) async {
    await ApiClient.instance.delete('/api/moi/moyens-paiement/$id');
  }
}

