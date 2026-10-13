/// Modèle d'une participation de commerçant à un groupe d'achat (ParticipationVue du backend, RG-26 à RG-32)
class ParticipationModel {
  final int id;
  final int groupeId;
  final String produit;
  final String sku;
  final String taille;
  final String couleur;
  final int quantite;
  final String statut; // DEMANDEE, RESERVEE, CONFIRMEE, ANNULEE
  final double prixUnitaire;
  final double montant;
  final DateTime? expirationReservation;
  final DateTime? dateCreation;

  const ParticipationModel({
    required this.id,
    required this.groupeId,
    required this.produit,
    this.sku = '',
    this.taille = '',
    this.couleur = '',
    required this.quantite,
    required this.statut,
    required this.prixUnitaire,
    required this.montant,
    this.expirationReservation,
    this.dateCreation,
  });

  factory ParticipationModel.fromJson(Map<String, dynamic> json) {
    int entier(Object? v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    double decimal(Object? v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    return ParticipationModel(
      id: entier(json['id']),
      groupeId: entier(json['groupeId']),
      produit: json['produit']?.toString() ?? 'Produit',
      sku: json['sku']?.toString() ?? '',
      taille: json['taille']?.toString() ?? '',
      couleur: json['couleur']?.toString() ?? '',
      quantite: entier(json['quantite']),
      statut: json['statut']?.toString() ?? 'DEMANDEE',
      prixUnitaire: decimal(json['prixUnitaire']),
      montant: decimal(json['montant']),
      expirationReservation: DateTime.tryParse(json['expirationReservation']?.toString() ?? ''),
      dateCreation: DateTime.tryParse(json['dateCreation']?.toString() ?? ''),
    );
  }

  /// Indique si la participation peut être annulée sans pénalité (RG-31)
  bool get estAnnulable => statut == 'RESERVEE' || statut == 'CONFIRMEE' || statut == 'DEMANDEE';

  /// Indique si les fonds sont déjà déposés en séquestre
  bool get estPayee => statut == 'CONFIRMEE';

  /// Indique si la commande a été annulée
  bool get estAnnulee => statut == 'ANNULEE';

  /// Libellé des détails variantes & quantité
  String get detailsVariante {
    final elements = <String>[];
    if (taille.isNotEmpty && taille != 'Standard' && taille != 'Unique') {
      elements.add('Taille $taille');
    }
    if (couleur.isNotEmpty && couleur != 'Standard' && couleur != 'Unique') {
      elements.add(couleur);
    }
    elements.add('Qté: $quantite');
    return elements.join(' • ');
  }

  /// Statut lisible et compréhensible pour le commerçant
  String get libelleStatut => switch (statut) {
        'DEMANDEE' => 'En attente de réservation',
        'RESERVEE' => 'Réservé • En attente de paiement',
        'CONFIRMEE' => 'Payé • Séquestre actif',
        'ANNULEE' => 'Annulé • Remboursé',
        _ => statut,
      };
}

