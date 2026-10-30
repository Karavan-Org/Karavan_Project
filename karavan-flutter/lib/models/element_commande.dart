import 'participation_model.dart';
import 'remboursement_model.dart';

/// Modèle unifié pour l'affichage d'une commande ou participation de commerçant
class ElementCommande {
  final int id;
  final bool estParticipation;
  final int? participationId;
  final int? commandeId;
  final String titre;
  final String details;
  final String numero;
  final String statutBrut;
  final String statutLibelle;
  final double montant;
  final int quantite;
  final String? photoUrl;
  final String imageLocale;
  final int etapeActive;
  final String origine;
  final String destination;
  final String arriveeEstimee;
  final bool annulable;
  final bool payee;
  final bool annulee;
  final RemboursementModel? remboursement;
  final DateTime? dateCreation;

  ElementCommande({
    required this.id,
    required this.estParticipation,
    this.participationId,
    this.commandeId,
    required this.titre,
    required this.details,
    required this.numero,
    required this.statutBrut,
    required this.statutLibelle,
    required this.montant,
    required this.quantite,
    this.photoUrl,
    required this.imageLocale,
    required this.etapeActive,
    this.origine = 'Chine (Yiwu)',
    this.destination = 'Bamako (Mali)',
    this.arriveeEstimee = 'En attente d\'expédition',
    required this.annulable,
    required this.payee,
    required this.annulee,
    this.remboursement,
    this.dateCreation,
  });

  static String _imagePourProduit(String nom) {
    final lower = nom.toLowerCase();
    if (lower.contains('sac') || lower.contains('maroquinerie') || lower.contains('portefeuille')) {
      return 'assets/images/wallet.jpg';
    }
    if (lower.contains('botte') || lower.contains('boot')) {
      return 'assets/images/black-dress-boots-2-mob.jpg';
    }
    if (lower.contains('robe') || lower.contains('dress') || lower.contains('abaya') || lower.contains('habit') || lower.contains('tissu')) {
      return 'assets/images/soft-elegance-abaya-coat-nida-purple-noor-and-grace.webp';
    }
    if (lower.contains('sandale') || lower.contains('talon') || lower.contains('claquette')) {
      return 'assets/images/sandales-talon-rouge.jpg';
    }
    if (lower.contains('cahier') || lower.contains('livre') || lower.contains('papeterie') || lower.contains('fourniture')) {
      return 'assets/images/images.jfif';
    }
    if (lower.contains('montre') || lower.contains('bijou') || lower.contains('accessoire')) {
      return 'assets/images/Montre-Homme-Quartz-Acier-Inoxydable-Cadran-Rond-Affichage-Analogique-Et-Num-rique-Boucle-Pliante-Simple-Cristal-Renforc-Nihaojewelry-France.webp';
    }
    if (lower.contains('chaussure') || lower.contains('basket') || lower.contains('sneaker') || lower.contains('shoes') || lower.contains('lex') || lower.contains('nike') || lower.contains('bueno')) {
      return 'assets/images/Nike_Joyride-removebg-preview.png';
    }
    return 'assets/images/logo_karavan.png';
  }

  factory ElementCommande.fromParticipation(ParticipationModel p, {RemboursementModel? remboursement, String? photoUrl}) {
    final parts = <String>[];
    if (p.detailsVariante.isNotEmpty) parts.add(p.detailsVariante);
    if (p.montant > 0) parts.add('${p.montant.toStringAsFixed(0)} FCFA');

    int etape = 0;
    String arrivee = 'En attente de regroupement';
    String statutLibelle = p.libelleStatut;

    if (p.statut == 'CONFIRMEE') {
      arrivee = 'Fonds en séquestre • En attente clôture groupe';
    } else if (p.statut == 'ANNULEE') {
      if (remboursement != null) {
        if (remboursement.statut == 'DEMANDE') {
          statutLibelle = 'Remboursement en traitement';
          arrivee = 'En cours d\'examen par l\'administrateur';
        } else if (remboursement.statut == 'APPROUVE') {
          statutLibelle = 'Remboursement approuvé';
          arrivee = 'Virement vers votre Mobile Money en cours';
        } else if (remboursement.statut == 'EXECUTE') {
          statutLibelle = 'Remboursé sur Mobile Money';
          arrivee = 'Montant de ${remboursement.montant.toStringAsFixed(0)} FCFA restitué';
        } else if (remboursement.statut == 'REJETE') {
          statutLibelle = 'Demande de remboursement rejetée';
          arrivee = 'Veuillez contacter le support Karavan';
        }
      } else {
        arrivee = 'Participation annulée • Remboursement';
      }
    } else if (p.statut == 'RESERVEE') {
      arrivee = 'Réservé • En attente de paiement';
    }

    final effectivePhoto = (photoUrl != null && photoUrl.isNotEmpty)
        ? photoUrl
        : ((p.photoUrl != null && p.photoUrl!.isNotEmpty) ? p.photoUrl : null);

    return ElementCommande(
      id: p.id,
      estParticipation: true,
      participationId: p.id,
      titre: p.produit,
      details: parts.join(' • '),
      numero: 'Participation #${p.id}',
      statutBrut: p.statut,
      statutLibelle: statutLibelle,
      montant: p.montant,
      quantite: p.quantite,
      photoUrl: effectivePhoto,
      imageLocale: _imagePourProduit(p.produit),
      etapeActive: etape,
      arriveeEstimee: arrivee,
      annulable: p.estAnnulable,
      payee: p.estPayee,
      annulee: p.estAnnulee,
      remboursement: remboursement,
      dateCreation: p.dateCreation,
    );
  }

  factory ElementCommande.fromCommande(Map<String, dynamic> c, {String? photoUrl}) {
    final id = (c['id'] as num?)?.toInt() ?? 1;
    final partId = (c['participationId'] as num?)?.toInt();
    final produit = c['produit']?.toString() ?? 'Commande groupée';
    final qte = (c['quantite'] as num?)?.toInt() ?? 1;
    final statut = c['statut']?.toString() ?? 'CREEE';

    final parts = <String>[];
    if (c['taille'] != null && c['taille'].toString().isNotEmpty) {
      parts.add('Taille ${c['taille']}');
    }
    if (c['couleur'] != null && c['couleur'].toString().isNotEmpty) {
      parts.add('${c['couleur']}');
    }
    parts.add('Qté: $qte');

    int etape = 1;
    String libelle = 'En cours';
    String arrivee = 'En cours de préparation';

    switch (statut) {
      case 'CREEE':
        etape = 0;
        libelle = 'Commande confirmée';
        arrivee = 'Regroupement finalisé';
        break;
      case 'EN_PREPARATION':
        etape = 1;
        libelle = 'Chez le transitaire';
        arrivee = 'Préparation en cours';
        break;
      case 'EXPEDIEE':
        etape = 2;
        libelle = 'En transit maritime/aérien';
        arrivee = 'Arrivée estimée : sous 10 à 15 jours';
        break;
      case 'ARRIVEE':
        etape = 3;
        libelle = 'Arrivée à Bamako';
        arrivee = 'Au centre de tri';
        break;
      case 'EN_ATTENTE_RETRAIT':
        etape = 4;
        libelle = 'Disponible au retrait';
        arrivee = 'Prêt au point de retrait';
        break;
      case 'COLLECTEE':
        etape = 4;
        libelle = 'Colis retiré';
        arrivee = 'Retrait effectué';
        break;
    }

    final String? cPhoto = c['photoUrl']?.toString();
    final effectivePhoto = (photoUrl != null && photoUrl.isNotEmpty)
        ? photoUrl
        : ((cPhoto != null && cPhoto.isNotEmpty) ? cPhoto : null);

    return ElementCommande(
      id: id,
      estParticipation: false,
      commandeId: id,
      participationId: partId,
      titre: produit,
      details: parts.join(' • '),
      numero: 'Commande #$id',
      statutBrut: statut,
      statutLibelle: libelle,
      montant: 0.0,
      quantite: qte,
      photoUrl: effectivePhoto,
      imageLocale: _imagePourProduit(produit),
      etapeActive: etape,
      arriveeEstimee: arrivee,
      annulable: false, // Une fois en commande logistique, l'annulation libre n'est plus permise (RG-31)
      payee: true,
      annulee: false,
      dateCreation: DateTime.tryParse(c['dateCreation']?.toString() ?? ''),
    );
  }
}

