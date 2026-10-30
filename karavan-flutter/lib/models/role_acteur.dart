/// Les 3 acteurs de l'écosystème Karavan
enum RoleActeur {
  commercant(
    libelle: 'Commerçant',
    description: 'Achetez en groupe à prix usine',
    titreAccueil: 'Des opportunités pour votre commerce',
    sousTitreAccueil:
        "Achetez en groupe, à prix de gros.",
  ),
  grossiste(
    libelle: 'Grossiste',
    description: 'Vendez vos stocks en gros à l\'international',
    titreAccueil: 'Développez vos ventes à l\'international',
    sousTitreAccueil:
        'Vendez vos stocks en gros à des milliers de commerçants, sécurisez vos paiements par séquestre bancaire et expédiez sans risque.',
  ),
  courtier(
    libelle: 'Courtier',
    description: 'Organisez les groupes, transit & retraits',
    titreAccueil: 'Votre partenaire dans l\'import-export',
    sousTitreAccueil:
        'Publiez vos offres, gérez vos groupes d\'achat et suivez vos commandes en toute simplicité.',
  );

  final String libelle;
  final String description;
  final String titreAccueil;
  final String sousTitreAccueil;

  const RoleActeur({
    required this.libelle,
    required this.description,
    required this.titreAccueil,
    required this.sousTitreAccueil,
  });

  String get codeBackend => switch (this) {
        RoleActeur.commercant => 'COMMERCANT',
        RoleActeur.grossiste => 'GROSSISTE',
        RoleActeur.courtier => 'COURTIER',
      };

  /// RG-03 : seul le Grossiste et le Courtier sont soumis à la validation KYC de l'administration.
  /// Le Commerçant accède directement à son espace dès la vérification de son numéro.
  bool get exigeValidation =>
      this == RoleActeur.grossiste || this == RoleActeur.courtier;

  /// Critères de validation respectifs selon le rôle (RG-04).
  String get criteresValidation => switch (this) {
        RoleActeur.grossiste =>
          "Pièce d'identité, justificatif d'activité (RCCM) et attestation NIF",
        RoleActeur.courtier =>
          "Pièce d'identité et licence de transitaire / commissionnaire",
        RoleActeur.commercant => '',
      };
}
