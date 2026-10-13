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

  const UtilisateurProfil({
    required this.id,
    required this.type,
    required this.nom,
    required this.telephone,
    this.photoUrl,
    required this.statut,
    this.permissions = const [],
  });

  factory UtilisateurProfil.fromJson(Map<String, dynamic> json) {
    return UtilisateurProfil(
      id: json['id'] as int? ?? 1,
      type: json['type'] as String? ?? 'COMMERCANT',
      nom: json['nom'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      statut: json['statut'] as String? ?? 'ACTIF',
      permissions: (json['permissions'] as List<dynamic>?)?.map((p) => p.toString()).toList() ?? [],
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
  };

  UtilisateurProfil copyWith({
    int? id,
    String? type,
    String? nom,
    String? telephone,
    String? photoUrl,
    String? statut,
    List<String>? permissions,
  }) {
    return UtilisateurProfil(
      id: id ?? this.id,
      type: type ?? this.type,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      photoUrl: photoUrl ?? this.photoUrl,
      statut: statut ?? this.statut,
      permissions: permissions ?? this.permissions,
    );
  }

  String get nomComplet => nom;
  String? get structure => null;

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

