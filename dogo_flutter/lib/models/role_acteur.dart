/// Les 3 acteurs de l'écosystème DoGo
enum RoleActeur {
  commercant(
    libelle: 'Commerçant',
    description: 'Achetez en groupe à prix usine',
    titreAccueil: 'Des opportunités pour votre commerce',
    sousTitreAccueil:
        "Rejoignez des groupes d'achat et accédez à des produits de qualité à des prix imbattables, depuis l'international.",
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
}
