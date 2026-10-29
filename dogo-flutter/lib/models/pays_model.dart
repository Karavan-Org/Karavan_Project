/// Pays du référentiel serveur (table `pays`) proposé comme origine d'un groupe d'achat.
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
}
