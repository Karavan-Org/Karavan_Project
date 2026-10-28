import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Les 3 niveaux de progression d'un Commerçant sur la plateforme Karavan
/// Basés sur le volume de commandes finalisées :
/// - Niveau 1 (Nouveau Commerçant) : < 5 commandes
/// - Niveau 2 (Commerçant Vérifié) : 5 à 19 commandes
/// - Niveau 3 (Commerçant VIP) : 20 commandes et plus
enum NiveauCommercant {
  niveau1(
    numero: 1,
    titre: 'Niveau 1',
    sousTitre: 'Nouveau Commerçant',
    description: 'Accédez aux achats groupés sécurisés par séquestre et achetez vos stocks au prix usine.',
    couleurBadge: AppTheme.terreDouce, // Ardoise doux
    icone: Icons.verified_user_outlined,
    seuilMin: 0,
    seuilSuivant: 5,
    nomNiveauSuivant: 'Niveau 2 • Vérifié',
    avantages: [
      'Accès libre à l\'ensemble des groupes d\'achat et arrivages',
      'Paiements 100% sécurisés sous compte séquestre bancaire Karavan',
      'Retrait sécurisé par QR code et code PIN aux points relais de Bamako',
      'Assistance utilisateur standard et suivi d\'acheminement en temps réel',
    ],
    avantagesSuivants: [
      'Priorité d\'attribution sur les quotas de conteneurs très demandés',
      'Badge officiel "Commerçant Vérifié" certifiant votre profil',
      'Tarifs préférentiels négociés sur le transport et la logistique',
    ],
  ),
  niveau2(
    numero: 2,
    titre: 'Niveau 2',
    sousTitre: 'Commerçant Vérifié',
    description: 'Commerçant actif et fidèle. Vous bénéficiez d\'une priorité sur les arrivages et d\'un badge vérifié.',
    couleurBadge: AppTheme.bissap, // Terre cuite cuivrée originale de la maquette Figma
    icone: Icons.stars_rounded,
    seuilMin: 5,
    seuilSuivant: 20,
    nomNiveauSuivant: 'Niveau 3 • VIP',
    avantages: [
      'Tous les avantages du Niveau 1',
      'Badge officiel "Commerçant Vérifié" renforçant votre crédibilité',
      'Priorité d\'attribution sur les campagnes et conteneurs à forte demande',
      'Alertes instantanées dès l\'ouverture des nouvelles opportunités',
      'Tarifs préférentiels négociés avec les grossistes partenaires',
    ],
    avantagesSuivants: [
      'Facilités de paiement & délais de règlement négociés avec le courtier',
      'Sourcing sur-mesure d\'usines partenaires en Chine, Turquie et Dubaï',
      'Gestionnaire de compte et assistance logistique dédiée 7j/7',
    ],
  ),
  niveau3(
    numero: 3,
    titre: 'Niveau 3',
    sousTitre: 'Commerçant VIP',
    description: 'Partenaire commercial privilégié d\'élite. Accédez au sourcing direct usine et à un accompagnement d\'exception.',
    couleurBadge: AppTheme.ocreProfond, // Doré ambré prestige
    icone: Icons.workspace_premium_rounded,
    seuilMin: 20,
    seuilSuivant: null,
    nomNiveauSuivant: null,
    avantages: [
      'Tous les avantages des Niveaux 1 et 2 inclus',
      'Badge suprême "Commerçant VIP" accordé aux plus grands acheteurs',
      'Facilités de trésorerie & délais de règlement négociés sur-mesure',
      'Sourcing direct usine Chine, Turquie, Dubaï à la demande',
      'Traitement prioritaire VIP au déchargement et mise à disposition rapide',
      'Gestionnaire commercial et logistique dédié joignable 7j/7',
    ],
    avantagesSuivants: [],
  );

  final int numero;
  final String titre;
  final String sousTitre;
  final String description;
  final Color couleurBadge;
  final IconData icone;
  final int seuilMin;
  final int? seuilSuivant;
  final String? nomNiveauSuivant;
  final List<String> avantages;
  final List<String> avantagesSuivants;

  const NiveauCommercant({
    required this.numero,
    required this.titre,
    required this.sousTitre,
    required this.description,
    required this.couleurBadge,
    required this.icone,
    required this.seuilMin,
    required this.seuilSuivant,
    required this.nomNiveauSuivant,
    required this.avantages,
    required this.avantagesSuivants,
  });

  /// Détermine dynamiquement le niveau à partir du nombre de commandes complétées
  static NiveauCommercant calculer(int nbCommandes) {
    if (nbCommandes >= 20) {
      return NiveauCommercant.niveau3;
    } else if (nbCommandes >= 5) {
      return NiveauCommercant.niveau2;
    } else {
      return NiveauCommercant.niveau1;
    }
  }

  /// Ratio de progression (entre 0.0 et 1.0) vers le prochain palier
  double progression(int nbCommandes) {
    if (seuilSuivant == null) return 1.0;
    return (nbCommandes / seuilSuivant!).clamp(0.0, 1.0);
  }

  /// Pourcentage formaté (ex: "60%")
  int pourcentageProgression(int nbCommandes) {
    return (progression(nbCommandes) * 100).round();
  }

  /// Nombre de commandes restantes pour débloquer le prochain niveau
  int commandesRestantesPourSuivant(int nbCommandes) {
    if (seuilSuivant == null) return 0;
    final restantes = seuilSuivant! - nbCommandes;
    return restantes > 0 ? restantes : 0;
  }
}

