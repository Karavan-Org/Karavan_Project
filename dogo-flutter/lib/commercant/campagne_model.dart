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
    this.paysOrigine = "",
    this.courtierNom = "",
    this.grossisteNom = "",
    this.tempsRestant = "",
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

    // Photo réelle du produit (servie par le backend) ; à défaut, le logo dɔgɔ
    String resolveImage() {
      final photo = produit?['photoUrl']?.toString() ?? json['imagePath']?.toString() ?? '';
      return photo.isNotEmpty ? photo : 'assets/images/logo_dogo.png';
    }

    String resolveTempsRestant() {
      if (json['tempsRestant'] is String) return json['tempsRestant'] as String;
      final limite = DateTime.tryParse(json['dateLimite']?.toString() ?? '');
      if (limite == null) return '';
      final reste = limite.difference(DateTime.now());
      if (reste.isNegative) return 'Clôturé';
      if (reste.inDays >= 1) return '${reste.inDays} jour${reste.inDays > 1 ? 's' : ''} restant${reste.inDays > 1 ? 's' : ''}';
      return '${reste.inHours} h restantes';
    }

    return GroupeCampagneModel(
      id: json['id']?.toString() ?? '1',
      // Titre choisi par le créateur du groupe (le backend renvoie le nom du produit à défaut)
      titre: json['titre'] as String? ?? produit?['nom'] as String? ?? 'Lot Import Groupé',
      sousTitre: produit?['description'] as String? ?? json['sousTitre'] as String? ?? 'Achat groupé international B2B',
      imagePath: resolveImage(),
      prixGroupe: pGroupe,
      prixPublic: pPublic,
      quantiteActuelle: qteActuelle,
      quantiteObjectif: qteCible > 0 ? qteCible : 100,
      categorie: produit?['categorie'] as String? ?? json['categorie'] as String? ?? 'Général',
      paysOrigine: produit?['paysOrigine'] as String? ?? json['paysOrigine'] as String? ?? '',
      // Groupe porté par un grossiste (sans courtier) : c'est lui qui achemine la marchandise
      courtierNom: courtier?['nom'] as String? ?? json['courtierNom'] as String? ?? grossiste?['nom'] as String? ?? '',
      grossisteNom: grossiste?['nom'] as String? ?? json['grossisteNom'] as String? ?? '',
      tempsRestant: resolveTempsRestant(),
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
