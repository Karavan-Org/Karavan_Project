import 'role_acteur.dart';

/// Profil de l'utilisateur connecté selon le contrat Spring Boot (ml.dogo.identite)
class UtilisateurProfil {
  final int id;
  final String type; // COMMERCANT, GROSSISTE, COURTIER, ADMINISTRATEUR
  final String nom;
  final String telephone;
  final String? photoUrl;
  final String statut;
  final List<String> permissions;
  final String? nomStructure;
  final String? quartier;

  const UtilisateurProfil({
    required this.id,
    required this.type,
    required this.nom,
    required this.telephone,
    this.photoUrl,
    required this.statut,
    this.permissions = const [],
    this.nomStructure,
    this.quartier,
  });

  factory UtilisateurProfil.fromJson(Map<String, dynamic> json) {
    String? struct;
    String? q;

    final details = json['details'];
    if (details is Map<String, dynamic>) {
      struct = details['nomBoutique']?.toString() ??
          details['nomBoutiqueMarche']?.toString() ??
          details['nomSocieteImport']?.toString();
      q = details['quartierBamako']?.toString();
    }

    struct ??= json['nomBoutique']?.toString() ??
        json['nomBoutiqueMarche']?.toString() ??
        json['nomSocieteImport']?.toString() ??
        json['nomStructure']?.toString() ??
        json['structure']?.toString();

    q ??= json['quartierBamako']?.toString() ?? json['quartier']?.toString();

    return UtilisateurProfil(
      id: json['id'] as int? ?? 1,
      type: json['type'] as String? ?? 'COMMERCANT',
      nom: json['nom'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      statut: json['statut'] as String? ?? 'ACTIF',
      permissions: (json['permissions'] as List<dynamic>?)?.map((p) => p.toString()).toList() ?? [],
      nomStructure: struct,
      quartier: q,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'nom': nom,
    'telephone': telephone,
    'photoUrl': photoUrl,
    'statut': statut,
    'permissions': permissions,
    'nomStructure': nomStructure,
    'quartier': quartier,
  };

  UtilisateurProfil copyWith({
    int? id,
    String? type,
    String? nom,
    String? telephone,
    String? photoUrl,
    String? statut,
    List<String>? permissions,
    String? nomStructure,
    String? quartier,
  }) {
    return UtilisateurProfil(
      id: id ?? this.id,
      type: type ?? this.type,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      photoUrl: photoUrl ?? this.photoUrl,
      statut: statut ?? this.statut,
      permissions: permissions ?? this.permissions,
      nomStructure: nomStructure ?? this.nomStructure,
      quartier: quartier ?? this.quartier,
    );
  }

  /// Même profil sans photo personnalisée ([copyWith] ne sait pas remettre un champ à null).
  UtilisateurProfil sansPhoto() => UtilisateurProfil(
        id: id,
        type: type,
        nom: nom,
        telephone: telephone,
        statut: statut,
        permissions: permissions,
        nomStructure: nomStructure,
        quartier: quartier,
      );

  String get nomComplet => nom;
  String? get structure => nomStructure;

  RoleActeur get roleActeur {
    switch (type.toUpperCase()) {
      case 'GROSSISTE':
        return RoleActeur.grossiste;
      case 'COURTIER':
        return RoleActeur.courtier;
      case 'COMMERCANT':
      default:
        return RoleActeur.commercant;
    }
  }
}

