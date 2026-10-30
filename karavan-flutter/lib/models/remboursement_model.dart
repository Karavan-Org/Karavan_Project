/// Modèle d'un remboursement financier (RemboursementVue du backend, RG-57 à RG-60)
class RemboursementModel {
  final int id;
  final int paiementId;
  final int? participationId;
  final int? groupeId;
  final String? produitNom;
  final double montant;
  final String statut; // DEMANDE, APPROUVE, EXECUTE, REJETE
  final String motif;
  final DateTime? dateDemande;

  const RemboursementModel({
    required this.id,
    required this.paiementId,
    this.participationId,
    this.groupeId,
    this.produitNom,
    required this.montant,
    required this.statut,
    required this.motif,
    this.dateDemande,
  });

  factory RemboursementModel.fromJson(Map<String, dynamic> json) {
    int entier(Object? v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    double decimal(Object? v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    return RemboursementModel(
      id: entier(json['id']),
      paiementId: entier(json['paiementId']),
      participationId: json['participationId'] != null ? entier(json['participationId']) : null,
      groupeId: json['groupeId'] != null ? entier(json['groupeId']) : null,
      produitNom: json['produitNom']?.toString(),
      montant: decimal(json['montant']),
      statut: json['statut']?.toString() ?? 'DEMANDE',
      motif: json['motif']?.toString() ?? '',
      dateDemande: DateTime.tryParse(json['dateDemande']?.toString() ?? ''),
    );
  }

  /// La demande est en attente ou en cours d'approbation administrative
  bool get enTraitement => statut == 'DEMANDE' || statut == 'APPROUVE';

  /// Le remboursement a été validé et exécuté vers le compte Mobile Money
  bool get execute => statut == 'EXECUTE';

  /// Le remboursement a été rejeté par l'administration
  bool get rejete => statut == 'REJETE';

  /// Libellé clair pour le commerçant
  String get libelleStatut => switch (statut) {
        'DEMANDE' => 'En cours de traitement par l\'administrateur',
        'APPROUVE' => 'Approuvé • Virement en cours',
        'EXECUTE' => 'Remboursé • Transféré sur Mobile Money',
        'REJETE' => 'Demande rejetée',
        _ => statut,
      };
}

