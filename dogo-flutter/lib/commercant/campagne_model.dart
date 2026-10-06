/// Modèle d'un groupe d'achat / campagne d'importation groupée, compatible API Backend DoGo
class GroupeCampagneModel {
  final String id;
  final String titre;
  final String sousTitre;
  final String imagePath;
  final int prixGroupe;
  final int prixPublic;
  final int quantiteActuelle;
  final int quantiteObjectif;
  final String categorie;
  final String paysOrigine;
  final String courtierNom;
  final String grossisteNom;
  final String tempsRestant;
  final int? varianteId;

  const GroupeCampagneModel({
    required this.id,
    required this.titre,
    required this.sousTitre,
    required this.imagePath,
    required this.prixGroupe,
    required this.prixPublic,
    required this.quantiteActuelle,
    required this.quantiteObjectif,
    required this.categorie,
    this.paysOrigine = "Istanbul, Turquie",
    this.courtierNom = "Touré Transit & Logistique SARL",
    this.grossisteNom = "Grossiste Cissé & Fils (Turquie)",
    this.tempsRestant = "3 jours restants",
    this.varianteId,
  });

  /// Usine de désérialisation depuis le JSON de l'API Backend Spring Boot (`GroupeVue`)
  factory GroupeCampagneModel.fromJson(Map<String, dynamic> json) {
    final produit = json['produit'] as Map<String, dynamic>?;
    final courtier = json['courtier'] as Map<String, dynamic>?;
    final grossiste = json['grossiste'] as Map<String, dynamic>?;

    int? vId;
    if (produit != null && produit['variantes'] is List && (produit['variantes'] as List).isNotEmpty) {
      final premiereVariante = (produit['variantes'] as List).first as Map<String, dynamic>?;
      vId = premiereVariante?['id'] as int?;
    }

    final rawPrixUnitaire = json['prixUnitaire'] ?? json['prixGroupe'];
    final int pGroupe = rawPrixUnitaire is num ? rawPrixUnitaire.toInt() : int.tryParse(rawPrixUnitaire?.toString() ?? '0') ?? 0;

    final rawPrixPublic = json['prixPublic'];
    final int pPublic = rawPrixPublic is num
        ? rawPrixPublic.toInt()
        : (pGroupe > 0 ? (pGroupe * 1.45).round() : 0);

    final rawQteActuelle = json['quantiteConfirmee'] ?? json['quantiteActuelle'];
    final int qteActuelle = rawQteActuelle is num ? rawQteActuelle.toInt() : int.tryParse(rawQteActuelle?.toString() ?? '0') ?? 0;

    final rawQteCible = json['quantiteCible'] ?? json['quantiteObjectif'];
    final int qteCible = rawQteCible is num ? rawQteCible.toInt() : int.tryParse(rawQteCible?.toString() ?? '100') ?? 100;

    // Association intelligente d'image selon la catégorie
    String resolveImage() {
      final img = json['imagePath']?.toString() ?? '';
      if (img.isNotEmpty) return img;

      final cat = (produit?['categorie'] ?? json['categorie'] ?? '').toString().toLowerCase();
      if (cat.contains('chauss') || cat.contains('sneaker')) {
        return 'assets/images/Nike_Joyride-removebg-preview.png';
      }
      if (cat.contains('mode') || cat.contains('abaya') || cat.contains('robe')) {
        return 'assets/images/soft-elegance-abaya-coat-nida-purple-noor-and-grace.webp';
      }
      if (cat.contains('maroquinerie') || cat.contains('sac')) {
        return 'assets/images/wallet.jpg';
      }
      return 'assets/images/logo_dogo.png';
    }

    return GroupeCampagneModel(
      id: json['id']?.toString() ?? '1',
      titre: produit?['nom'] as String? ?? json['titre'] as String? ?? 'Lot Import Groupé',
      sousTitre: produit?['description'] as String? ?? json['sousTitre'] as String? ?? 'Achat groupé international B2B',
      imagePath: resolveImage(),
      prixGroupe: pGroupe,
      prixPublic: pPublic,
      quantiteActuelle: qteActuelle,
      quantiteObjectif: qteCible > 0 ? qteCible : 100,
      categorie: produit?['categorie'] as String? ?? json['categorie'] as String? ?? 'Général',
      paysOrigine: produit?['paysOrigine'] as String? ?? json['paysOrigine'] as String? ?? 'Istanbul, Turquie',
      courtierNom: courtier?['nom'] as String? ?? json['courtierNom'] as String? ?? 'Touré Transit & Logistique SARL',
      grossisteNom: grossiste?['nom'] as String? ?? json['grossisteNom'] as String? ?? 'Grossiste Partenaire',
      tempsRestant: json['tempsRestant'] as String? ?? '3 jours restants',
      varianteId: vId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titre': titre,
    'sousTitre': sousTitre,
    'imagePath': imagePath,
    'prixGroupe': prixGroupe,
    'prixPublic': prixPublic,
    'quantiteActuelle': quantiteActuelle,
    'quantiteObjectif': quantiteObjectif,
    'categorie': categorie,
    'paysOrigine': paysOrigine,
    'courtierNom': courtierNom,
    'grossisteNom': grossisteNom,
    'tempsRestant': tempsRestant,
    if (varianteId != null) 'varianteId': varianteId,
  };

  double get ratio => (quantiteActuelle / quantiteObjectif).clamp(0.0, 1.0);
  int get reste => quantiteObjectif - quantiteActuelle;
}
