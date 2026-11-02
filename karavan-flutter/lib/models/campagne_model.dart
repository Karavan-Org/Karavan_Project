/// Alias pour compatibilité
typedef VarianteGroupe = VarianteGroupeModel;

/// Modèle d'une variante de produit renseignée par le grossiste (RG-12)
class VarianteGroupeModel {
  final int id;
  final String sku;
  final String taille;
  final String couleur;
  final int? qteDisponible;

  const VarianteGroupeModel({
    required this.id,
    required this.sku,
    required this.taille,
    required this.couleur,
    this.qteDisponible,
  });

  List<String> get _elements {
    final elements = <String>[];
    if (taille.isNotEmpty && taille.toLowerCase() != 'unique' && taille.toLowerCase() != 'standard') {
      elements.add(taille);
    } else if (taille.isNotEmpty) {
      elements.add(taille);
    }
    if (couleur.isNotEmpty && couleur.toLowerCase() != 'standard' && couleur.toLowerCase() != 'unique') {
      elements.add(couleur);
    }
    return elements;
  }

  /// Libellé concis avec séparateur point médian (utilisé par GroupeVue et API)
  String get libelle {
    final elems = _elements;
    if (elems.isEmpty) return sku.isNotEmpty ? sku : "Variante #$id";
    return elems.join(" · ");
  }

  /// Libellé d'affichage clair pour le commerçant
  String get libelleComplet {
    final elems = _elements;
    if (elems.isEmpty) return sku.isNotEmpty ? sku : "Variante #$id";
    return elems.join(" • ");
  }

  factory VarianteGroupeModel.fromJson(Map<String, dynamic> json) {
    return VarianteGroupeModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      sku: json['sku']?.toString() ?? '',
      taille: json['taille']?.toString() ?? '',
      couleur: json['couleur']?.toString() ?? '',
      qteDisponible: json['qteDisponible'] is num
          ? (json['qteDisponible'] as num).toInt()
          : (json['quantiteDisponible'] is num
              ? (json['quantiteDisponible'] as num).toInt()
              : (json['qteDisponible'] != null ? int.tryParse(json['qteDisponible'].toString()) : null)),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'taille': taille,
        'couleur': couleur,
        if (qteDisponible != null) 'qteDisponible': qteDisponible,
      };
}

/// Modèle d'un groupe d'achat / campagne d'importation groupée, compatible API Backend Karavan
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
  final String? courtierPhotoUrl;
  final String grossisteNom;
  final String? grossistePhotoUrl;
  final String tempsRestant;
  final int? varianteId;
  final List<VarianteGroupeModel> variantes;
  final int quantiteMinParCommercant;
  final int quantiteMaxParCommercant;
  final int? produitId;
  final String statut;
  final int? _quantiteRestante;

  int get quantiteRestante => _quantiteRestante ?? (quantiteObjectif - quantiteActuelle).clamp(0, quantiteObjectif);
  bool get aPrixPublic => prixPublic > 0;
  int get pourcentageEconomie =>
      prixPublic > prixGroupe && prixPublic > 0
          ? (((prixPublic - prixGroupe) / prixPublic) * 100).round()
          : 0;

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
    this.courtierPhotoUrl,
    this.grossisteNom = "",
    this.grossistePhotoUrl,
    this.tempsRestant = "",
    this.varianteId,
    this.variantes = const [],
    this.quantiteMinParCommercant = 1,
    this.quantiteMaxParCommercant = 1000,
    this.produitId,
    this.statut = "OUVERT",
    int? quantiteRestante,
  }) : _quantiteRestante = quantiteRestante;

  /// Usine de désérialisation depuis le JSON de l'API Backend Spring Boot (`GroupeVue`)
  factory GroupeCampagneModel.fromJson(Map<String, dynamic> json) {
    final produit = json['produit'] as Map<String, dynamic>?;
    final courtier = json['courtier'] as Map<String, dynamic>?;
    final grossiste = json['grossiste'] as Map<String, dynamic>?;
    final conditions = json['conditions'] as Map<String, dynamic>?;

    final List<VarianteGroupeModel> vars = [];
    final rawVariantes = produit?['variantes'] ?? json['variantes'];
    if (rawVariantes is List) {
      for (final item in rawVariantes) {
        if (item is Map<String, dynamic>) {
          vars.add(VarianteGroupeModel.fromJson(item));
        }
      }
    }

    int? vId = json['varianteId'] is num
        ? (json['varianteId'] as num).toInt()
        : int.tryParse(json['varianteId']?.toString() ?? '');
    if (vId == null && vars.isNotEmpty) {
      vId = vars.first.id;
    }

    final rawPrixUnitaire = json['prixUnitaire'] ?? json['prixGroupe'];
    final int pGroupe = rawPrixUnitaire is num
        ? rawPrixUnitaire.toInt()
        : int.tryParse(rawPrixUnitaire?.toString() ?? '0') ?? 0;

    final rawPrixPublic = json['prixPublic'];
    final int pPublic = rawPrixPublic is num
        ? rawPrixPublic.toInt()
        : (rawPrixPublic != null ? int.tryParse(rawPrixPublic.toString()) ?? 0 : 0);

    final int qteConfirmee = json['quantiteConfirmee'] is num
        ? (json['quantiteConfirmee'] as num).toInt()
        : int.tryParse(json['quantiteConfirmee']?.toString() ?? '0') ?? 0;
    final int qteReservee = json['quantiteReservee'] is num
        ? (json['quantiteReservee'] as num).toInt()
        : int.tryParse(json['quantiteReservee']?.toString() ?? '0') ?? 0;
    final int rawQteActuelle = json['quantiteActuelle'] is num
        ? (json['quantiteActuelle'] as num).toInt()
        : int.tryParse(json['quantiteActuelle']?.toString() ?? '0') ?? 0;

    // La jauge reflète toutes les pièces engagées (réservées + confirmées)
    final int qteActuelle = (qteConfirmee + qteReservee) > 0
        ? (qteConfirmee + qteReservee)
        : (rawQteActuelle > 0 ? rawQteActuelle : qteConfirmee);

    final rawQteCible = json['quantiteCible'] ?? json['quantiteObjectif'];
    final int qteCible = rawQteCible is num
        ? rawQteCible.toInt()
        : int.tryParse(rawQteCible?.toString() ?? '100') ?? 100;

    final rawQteRestante = json['quantiteRestante'];
    final int qteRestante = rawQteRestante is num
        ? rawQteRestante.toInt()
        : (qteCible - qteActuelle).clamp(0, qteCible);

    final rawQteMin = conditions?['quantiteMinParCommercant'] ?? json['quantiteMinParCommercant'];
    final int qteMin = rawQteMin is num
        ? rawQteMin.toInt()
        : int.tryParse(rawQteMin?.toString() ?? '1') ?? 1;

    final rawQteMax = conditions?['quantiteMaxParCommercant'] ?? json['quantiteMaxParCommercant'];
    int qteMax = rawQteMax is num
        ? rawQteMax.toInt()
        : qteRestante;
    if (qteMax > qteRestante) qteMax = qteRestante;

    final String statut = json['statut']?.toString() ?? 'OUVERT';

    final rawProduitId = produit?['id'] ?? json['produitId'];
    final int? pId = rawProduitId is num
        ? rawProduitId.toInt()
        : int.tryParse(rawProduitId?.toString() ?? '');

    // Photo réelle du produit (servie par le backend) ; à défaut la photo du vendeur, sinon logo Karavan
    String resolveImage() {
      final photo = produit?['photoUrl']?.toString() ?? json['imagePath']?.toString() ?? '';
      if (photo.isNotEmpty) return photo;
      final photoG = grossiste?['photoUrl']?.toString() ?? json['grossistePhotoUrl']?.toString() ?? '';
      if (photoG.isNotEmpty) return photoG;
      return 'assets/images/logo_karavan.png';
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

    final grossistePhoto = grossiste?['photoUrl']?.toString() ?? json['grossistePhotoUrl']?.toString();
    final courtierPhoto = courtier?['photoUrl']?.toString() ?? json['courtierPhotoUrl']?.toString();

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
      courtierPhotoUrl: courtierPhoto,
      grossisteNom: grossiste?['nom'] as String? ?? json['grossisteNom'] as String? ?? '',
      grossistePhotoUrl: grossistePhoto,
      tempsRestant: resolveTempsRestant(),
      varianteId: vId,
      variantes: vars,
      quantiteMinParCommercant: qteMin > 0 ? qteMin : 1,
      quantiteMaxParCommercant: qteMax > 0 ? qteMax : 1000,
      produitId: pId,
      statut: statut,
      quantiteRestante: qteRestante,
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
    'variantes': variantes.map((v) => v.toJson()).toList(),
    'quantiteMinParCommercant': quantiteMinParCommercant,
    'quantiteMaxParCommercant': quantiteMaxParCommercant,
    'quantiteRestante': quantiteRestante,
    'statut': statut,
    if (produitId != null) 'produitId': produitId,
  };

  double get ratio => (quantiteActuelle / quantiteObjectif).clamp(0.0, 1.0);
  int get reste => quantiteRestante;
}

