import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Modèle d'étape logistique prescrite dans le cycle de vie Karavan
class EtapeSuiviModel {
  final int numero;
  final String titre;
  final String sousTitre;
  final String lieu;
  final String dateHeure;
  final String acteurResponsable; // Grossiste, Administrateur, Courtier
  final IconData icone;

  const EtapeSuiviModel({
    required this.numero,
    required this.titre,
    required this.sousTitre,
    required this.lieu,
    required this.dateHeure,
    required this.acteurResponsable,
    required this.icone,
  });
}

/// Modèle complet d'un colis rattaché à un groupe d'achat
/// La jauge de progression est calculée dynamiquement sur le nombre d'étapes prescrites dédiées.
class ColisGroupeModel {
  final String idCommande;
  final String idGroupe;
  final String nomProduit;
  final String imagePath;
  final int quantite;
  final String pointRetrait;
  final String courtierNom;
  final String grossisteNom;
  final int etapeActuelle; // 1 à N
  final String derniereMiseAJourAdmin;
  final List<EtapeSuiviModel> etapesPrescrites;

  const ColisGroupeModel({
    required this.idCommande,
    required this.idGroupe,
    required this.nomProduit,
    required this.imagePath,
    required this.quantite,
    required this.pointRetrait,
    required this.courtierNom,
    required this.grossisteNom,
    required this.etapeActuelle,
    required this.derniereMiseAJourAdmin,
    required this.etapesPrescrites,
  });

  /// Nombre total d'étapes prescrites pour ce convoi / groupe
  int get nombreEtapesPrescrites => etapesPrescrites.length;

  /// Progression dynamique calculée sur le nombre d'étapes prescrites dédiées (0.0 à 1.0)
  double get pourcentageProgression => nombreEtapesPrescrites > 0
      ? (etapeActuelle / nombreEtapesPrescrites).clamp(0.0, 1.0)
      : 0.0;

  /// Pourcentage entier pour l'affichage (ex: 20%, 40%, 60%, 80%, 100% sur 5 étapes prescrites)
  int get pourcentageEntier => (pourcentageProgression * 100).round();

  /// Vérifie si toutes les étapes prescrites ont été franchies
  bool get estEntierementLivre => etapeActuelle >= nombreEtapesPrescrites;

  EtapeSuiviModel get etapeCourante => etapesPrescrites[
      (etapeActuelle - 1).clamp(0, nombreEtapesPrescrites - 1)];

  ColisGroupeModel copyWith({
    int? etapeActuelle,
    String? derniereMiseAJourAdmin,
    List<EtapeSuiviModel>? etapesPrescrites,
  }) {
    return ColisGroupeModel(
      idCommande: idCommande,
      idGroupe: idGroupe,
      nomProduit: nomProduit,
      imagePath: imagePath,
      quantite: quantite,
      pointRetrait: pointRetrait,
      courtierNom: courtierNom,
      grossisteNom: grossisteNom,
      etapeActuelle: etapeActuelle ?? this.etapeActuelle,
      derniereMiseAJourAdmin:
          derniereMiseAJourAdmin ?? this.derniereMiseAJourAdmin,
      etapesPrescrites: etapesPrescrites ?? this.etapesPrescrites,
    );
  }
}

/// Service réactif de suivi colis synchronisé avec les validations Grossiste & Administrateur
class SuiviColisService {
  SuiviColisService._internal();
  static final SuiviColisService instance = SuiviColisService._internal();

  /// 5 étapes prescrites officielles pour un convoi international vers Bamako
  static const List<EtapeSuiviModel> etapesPrescritesStandard = [
    EtapeSuiviModel(
      numero: 1,
      titre: "Groupe Clôturé & Paiements Séquestrés",
      sousTitre: "100% des quotas atteints, fonds bloqués sous séquestre Karavan",
      lieu: "Plateforme centrale Karavan (Bamako)",
      dateHeure: "26 Septembre - 18:00",
      acteurResponsable: "Validé par le Système Séquestre Karavan",
      icone: Icons.verified_user_outlined,
    ),
    EtapeSuiviModel(
      numero: 2,
      titre: "Préparation & Conditionnement Grossiste",
      sousTitre: "Inspection des lots, étiquetage codes barres Karavan et colisage",
      lieu: "Entrepôt Grossiste, Istanbul (Turquie)",
      dateHeure: "28 Septembre - 10:30",
      acteurResponsable: "Validé par Grossiste Bosphore Export",
      icone: Icons.inventory_2_outlined,
    ),
    EtapeSuiviModel(
      numero: 3,
      titre: "Fret Aérien International en Transit",
      sousTitre: "Vol Cargo TK-641 pris en charge, suivi satellite activé",
      lieu: "Espace aérien international (Vol TK-641)",
      dateHeure: "30 Septembre - 14:15",
      acteurResponsable: "Mis à jour par Admin Karavan & Courtier Touré",
      icone: Icons.flight_takeoff,
    ),
    EtapeSuiviModel(
      numero: 4,
      titre: "Arrivée Hub Douane Mali & Dédouanement",
      sousTitre: "Formalités douanières groupées validées et transfert urbain",
      lieu: "Plateforme Douanière de Bamako-Sénou",
      dateHeure: "01 Octobre - 09:00",
      acteurResponsable: "Validé par Administrateur Douanes Karavan",
      icone: Icons.fact_check_outlined,
    ),
    EtapeSuiviModel(
      numero: 5,
      titre: "Disponible au Point de Retrait",
      sousTitre: "Colis réceptionné au guichet Dabanani. Code PIN & QR débloqués.",
      lieu: "Magasin Dabanani, Porte 14 - Grand Marché Bamako",
      dateHeure: "02 Octobre - 11:20",
      acteurResponsable: "Mis à disposition par le Magasinier Relais",
      icone: Icons.storefront,
    ),
  ];

  final ValueNotifier<ColisGroupeModel?> colisActifNotifier =
      ValueNotifier<ColisGroupeModel?>(null);

  /// Fait avancer la jauge sur le nombre d'étapes prescrites dédiées
  void avancerEtapeSuivante(BuildContext context) {
    final actuel = colisActifNotifier.value;
    if (actuel == null) return;
    final total = actuel.nombreEtapesPrescrites;

    int nextEtape = actuel.etapeActuelle + 1;
    if (nextEtape > total) nextEtape = 1; // Boucle de démonstration

    final etapeModel = actuel.etapesPrescrites[nextEtape - 1];

    String miseAJourMessage;
    switch (nextEtape) {
      case 1:
        miseAJourMessage = "Groupe complété, fonds sécurisés.";
        break;
      case 2:
        miseAJourMessage = "Lot préparé par le grossiste.";
        break;
      case 3:
        miseAJourMessage = "Convoi embarqué en vol fret.";
        break;
      case 4:
        miseAJourMessage = "Dédouané, en route vers le point de retrait.";
        break;
      case 5:
        miseAJourMessage = "Colis arrivé ! Code de retrait activé.";
        break;
      default:
        miseAJourMessage = "Position du convoi actualisée.";
    }

    colisActifNotifier.value = actuel.copyWith(
      etapeActuelle: nextEtape,
      derniereMiseAJourAdmin: miseAJourMessage,
    );

    final nouveauPourcentage = (nextEtape / total * 100).round();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sync, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "${etapeModel.titre} • $nouveauPourcentage %",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
