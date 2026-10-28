/// Modèle de référence d'un Pays pour les achats groupés internationaux Karavan.
class PaysModel {
  final String codeIso;
  final String nomFr;
  final double latitude;
  final double longitude;
  final bool actif;

  const PaysModel({
    required this.codeIso,
    required this.nomFr,
    required this.latitude,
    required this.longitude,
    required this.actif,
  });

  factory PaysModel.fromJson(Map<String, dynamic> json) => PaysModel(
        codeIso: json['codeIso']?.toString() ?? '',
        nomFr: json['nomFr']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        actif: json['actif'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'codeIso': codeIso,
        'nomFr': nomFr,
        'latitude': latitude,
        'longitude': longitude,
        'actif': actif,
      };

  /// Drapeau approximatif ou emoji drapeau à partir du code ISO à 2 lettres
  String get drapeauEmoji {
    if (codeIso.length != 2) return '🌐';
    final int premier = codeIso.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = codeIso.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(premier) + String.fromCharCode(second);
  }
}

