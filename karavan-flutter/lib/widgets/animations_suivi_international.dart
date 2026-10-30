import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Définition canonique des 10 grandes phases communes à tout colis international
class PhaseColisInternational {
  final int numero;
  final String titre;
  final String description;
  final String sousTitre;
  final String lieuTypique;
  final IconData icone;
  final Color couleur;

  const PhaseColisInternational({
    required this.numero,
    required this.titre,
    required this.description,
    required this.sousTitre,
    required this.lieuTypique,
    required this.icone,
    required this.couleur,
  });

  static const List<PhaseColisInternational> toutes = [
    PhaseColisInternational(
      numero: 1,
      titre: "Commande reçue / en traitement",
      description: "Le vendeur confirme et prépare la marchandise.",
      sousTitre: "Vérification des stocks, étiquetage code-barres et emballage soigné en entrepôt.",
      lieuTypique: "Entrepôt du fournisseur (Pays d'origine)",
      icone: Icons.inventory_2_outlined,
      couleur: Color(0xFFD97706), // Ambre
    ),
    PhaseColisInternational(
      numero: 2,
      titre: "Expédié par le vendeur / pris en charge",
      description: "Le colis quitte le fournisseur ou est remis au transporteur ou au transitaire.",
      sousTitre: "Remise au transitaire logistique, bordereau d'enlèvement scellé.",
      lieuTypique: "Centre logistique de collecte fournisseur",
      icone: Icons.local_shipping_outlined,
      couleur: Color(0xFF2563EB), // Bleu transport
    ),
    PhaseColisInternational(
      numero: 3,
      titre: "Centre de départ (Tri & Regroupement)",
      description: "Tri dans le pays d’origine, regroupement.",
      sousTitre: "Consolidation des lots d'achat groupé et palettisation pour l'export.",
      lieuTypique: "Hub d'expédition international (Yiwu / Istanbul)",
      icone: Icons.hub_outlined,
      couleur: Color(0xFF475569), // Ardoise hub
    ),
    PhaseColisInternational(
      numero: 4,
      titre: "Départ du pays d’origine",
      description: "Aéroport, port ou frontière routière, selon le mode.",
      sousTitre: "Formalités de sortie validées, chargement dans l'avion cargo ou le navire.",
      lieuTypique: "Port de Ningbo / Aéroport international",
      icone: Icons.flight_takeoff_rounded,
      couleur: Color(0xFF0D9488), // Sarcelle départ
    ),
    PhaseColisInternational(
      numero: 5,
      titre: "En transit international",
      description: "Vol, traversée ou route. C’est la longue phase où il y a peu d’événements.",
      sousTitre: "Acheminement intercontinental en cours. Balisage et géolocalisation satellite actifs.",
      lieuTypique: "Espace maritime / Aérien international",
      icone: Icons.public_rounded,
      couleur: Color(0xFF0284C7), // Océan / Ciel
    ),
    PhaseColisInternational(
      numero: 6,
      titre: "Arrivée dans le pays de destination",
      description: "Aéroport, port ou poste frontière.",
      sousTitre: "Atterrissage ou accostage au port de transit / destination finale.",
      lieuTypique: "Port de Dakar / Aéroport Bamako-Sénou",
      icone: Icons.flight_land_rounded,
      couleur: Color(0xFF059669), // Émeraude arrivée
    ),
    PhaseColisInternational(
      numero: 7,
      titre: "Dédouanement & Contrôles",
      description: "Douane, taxes, contrôles. C’est souvent là que surviennent les blocages.",
      sousTitre: "Inspection douanière, apurement des droits de douane et déclarations groupées.",
      lieuTypique: "Poste de Douane Frontière / Bureau Central",
      icone: Icons.gavel_rounded,
      couleur: Color(0xFFDC2626), // Rouge vigilance douane
    ),
    PhaseColisInternational(
      numero: 8,
      titre: "Centre de tri du pays de destination",
      description: "Transfert vers la ville finale.",
      sousTitre: "Réception au centre de tri national et ventilation vers les points de distribution.",
      lieuTypique: "Plateforme logistique centrale de Bamako",
      icone: Icons.warehouse_rounded,
      couleur: Color(0xFFEA580C), // Orange distribution
    ),
    PhaseColisInternational(
      numero: 9,
      titre: "En livraison locale / disponible au retrait",
      description: "Dernier kilomètre, livreur ou point relais.",
      sousTitre: "Colis acheminé à votre point relais. Votre code de retrait et PIN sont activés.",
      lieuTypique: "Point Relais Dabanani / Grand Marché",
      icone: Icons.storefront_rounded,
      couleur: Color(0xFF16A34A), // Vert prêt
    ),
    PhaseColisInternational(
      numero: 10,
      titre: "Livré / retiré",
      description: "Remise effective du colis.",
      sousTitre: "Colis remis en main propre après vérification du code PIN / QR code secret.",
      lieuTypique: "Guichet de retrait - Clôture commande",
      icone: Icons.check_circle_rounded,
      couleur: Color(0xFF15803D), // Vert succès final
    ),
  ];

  static PhaseColisInternational depuisNumero(int num) {
    if (num < 1) return toutes.first;
    if (num > toutes.length) return toutes.last;
    return toutes[num - 1];
  }
}

// ============================================================================
// COMPOSANT MAÎTRE D'ANIMATION DE PHASE
// ============================================================================

/// Affiche l'animation interactive spécifique à la phase logistique demandée.
/// L'animation boucle en continu tant que l'écran ou la phase est active.
class AnimationPhaseWidget extends StatefulWidget {
  final int numeroPhase;
  final bool compact;
  final double? taille;

  const AnimationPhaseWidget({
    super.key,
    required this.numeroPhase,
    this.compact = false,
    this.taille,
  });

  @override
  State<AnimationPhaseWidget> createState() => _AnimationPhaseWidgetState();
}

class _AnimationPhaseWidgetState extends State<AnimationPhaseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AnimationPhaseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.numeroPhase != widget.numeroPhase) {
      _controller.reset();
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final num = widget.numeroPhase.clamp(1, 10);
    final dimension = widget.taille ?? (widget.compact ? 48.0 : 130.0);

    return SizedBox(
      width: dimension,
      height: dimension,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          switch (num) {
            case 1:
              return _AnimPhase1Traitement(controller: _controller, compact: widget.compact);
            case 2:
              return _AnimPhase2PriseEnCharge(controller: _controller, compact: widget.compact);
            case 3:
              return _AnimPhase3CentreDepart(controller: _controller, compact: widget.compact);
            case 4:
              return _AnimPhase4DepartOrigine(controller: _controller, compact: widget.compact);
            case 5:
              return _AnimPhase5TransitInternational(controller: _controller, compact: widget.compact);
            case 6:
              return _AnimPhase6ArriveeDestination(controller: _controller, compact: widget.compact);
            case 7:
              return _AnimPhase7Dedouanement(controller: _controller, compact: widget.compact);
            case 8:
              return _AnimPhase8CentreTri(controller: _controller, compact: widget.compact);
            case 9:
              return _AnimPhase9LivraisonLocale(controller: _controller, compact: widget.compact);
            case 10:
              return _AnimPhase10LivreRetire(controller: _controller, compact: widget.compact);
            default:
              return _AnimPhase1Traitement(controller: _controller, compact: widget.compact);
          }
        },
      ),
    );
  }
}

// ============================================================================
// 1. COMMANDE REÇUE / EN TRAITEMENT : Carton qui s'assemble & engrenages actifs
// ============================================================================
class _AnimPhase1Traitement extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase1Traitement({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    final scale = 1.0 + 0.05 * math.sin(t * 2 * math.pi);
    final rotation = t * 2 * math.pi;

    return Center(
      child: Transform.scale(
        scale: scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo de préparation
            Container(
              width: compact ? 36 : 95,
              height: compact ? 36 : 95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
              ),
            ),
            // Petit engrenage en rotation derrière
            if (!compact)
              Positioned(
                top: 14,
                right: 18,
                child: Transform.rotate(
                  angle: rotation,
                  child: const Icon(Icons.settings, size: 26, color: Color(0xFFFBBF24)),
                ),
              ),
            // Carton principal d'emballage
            Icon(
              Icons.inventory_2_rounded,
              size: compact ? 26 : 64,
              color: const Color(0xFFD97706),
            ),
            // Ruban adhésif / Checkmark qui pulse
            Positioned(
              bottom: compact ? 2 : 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 8, vertical: compact ? 1 : 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: compact ? 8 : 12, color: Colors.white),
                    if (!compact) ...[
                      const SizedBox(width: 3),
                      const Text(
                        "Colisage",
                        style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. EXPÉDIÉ PAR LE VENDEUR : Camionnette de ramassage roulant sur route animée
// ============================================================================
class _AnimPhase2PriseEnCharge extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase2PriseEnCharge({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    // Mouvement d'oscillation verticale de la suspension
    final rebond = math.sin(t * 4 * math.pi) * (compact ? 1.0 : 2.5);
    // Translation horizontale légère
    final transX = math.sin(t * 2 * math.pi) * (compact ? 2.0 : 6.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Route animée avec tirets défilants
          Positioned(
            bottom: compact ? 6 : 22,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(compact ? 48 : 120, 4),
              painter: _RouteAnimPainter(decalage: t),
            ),
          ),
          // Camionnette
          Transform.translate(
            offset: Offset(transX, rebond),
            child: Icon(
              Icons.local_shipping_rounded,
              size: compact ? 28 : 66,
              color: const Color(0xFF2563EB),
            ),
          ),
          // Petites volutes d'accélération
          if (!compact)
            Positioned(
              left: 12 - (t * 8),
              bottom: 28,
              child: Opacity(
                opacity: (1.0 - t).clamp(0.0, 1.0),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF93C5FD),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. CENTRE DE DÉPART : Tapis roulant de tri & contrôle des lots
// ============================================================================
class _AnimPhase3CentreDepart extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase3CentreDepart({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cercle d'arrière-plan du Hub
          Container(
            width: compact ? 36 : 95,
            height: compact ? 36 : 95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF475569).withValues(alpha: 0.1),
            ),
          ),
          // Hub / Entrepôt de tri
          Icon(
            Icons.hub_rounded,
            size: compact ? 26 : 60,
            color: const Color(0xFF475569),
          ),
          // Petit colis en cours de scan
          Positioned(
            bottom: compact ? 4 : 14,
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: compact ? 12 : 24,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. DÉPART DU PAYS D’ORIGINE : Avion cargo décollant avec traînée de propulsion
// ============================================================================
class _AnimPhase4DepartOrigine extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase4DepartOrigine({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    // Mouvement d'ascension
    final transX = (t - 0.5) * (compact ? 8.0 : 20.0);
    final transY = -t * (compact ? 6.0 : 16.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ligne de décollage inclinée
          Transform.rotate(
            angle: -0.35,
            child: Container(
              width: compact ? 38 : 90,
              height: compact ? 2 : 3,
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Avion cargo en ascension
          Transform.translate(
            offset: Offset(transX, transY),
            child: Transform.rotate(
              angle: -0.28,
              child: Icon(
                Icons.flight_takeoff_rounded,
                size: compact ? 28 : 64,
                color: const Color(0xFF0D9488),
              ),
            ),
          ),
          // Nuages défilants dessous
          if (!compact)
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_rounded, size: 16, color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Icon(Icons.cloud_rounded, size: 22, color: const Color(0xFF0D9488).withValues(alpha: 0.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. EN TRANSIT INTERNATIONAL : Globe rotatif, avion en orbite & ondes satellite
// ============================================================================
class _AnimPhase5TransitInternational extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase5TransitInternational({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    final angle = t * 2 * math.pi;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Globe central
          Container(
            width: compact ? 34 : 76,
            height: compact ? 34 : 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0284C7).withValues(alpha: 0.2),
                  const Color(0xFF0284C7).withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Icon(
              Icons.public_rounded,
              size: compact ? 26 : 58,
              color: const Color(0xFF0284C7),
            ),
          ),
          // Véhicule en orbite (avion ou navire en transit)
          Transform.rotate(
            angle: angle,
            child: Transform.translate(
              offset: Offset(0, -(compact ? 16.0 : 42.0)),
              child: Transform.rotate(
                angle: math.pi / 2,
                child: Icon(
                  Icons.airplanemode_active_rounded,
                  size: compact ? 12 : 24,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ),
          ),
          // Pulsation satellite
          if (!compact)
            Positioned(
              top: 6,
              right: 14,
              child: Icon(
                Icons.satellite_alt_rounded,
                size: 20,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.7 + 0.3 * math.sin(t * 4 * math.pi)),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. ARRIVÉE PAYS DE DESTINATION : Atterrissage sur piste avec balises lumineuses
// ============================================================================
class _AnimPhase6ArriveeDestination extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase6ArriveeDestination({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    // Approche vers le sol
    final transY = (t - 0.5) * (compact ? 4.0 : 12.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Piste d'atterrissage avec balises
          Positioned(
            bottom: compact ? 4 : 16,
            child: Container(
              width: compact ? 40 : 100,
              height: compact ? 4 : 8,
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Avion en descente
          Transform.translate(
            offset: Offset(0, transY),
            child: Transform.rotate(
              angle: 0.18,
              child: Icon(
                Icons.flight_land_rounded,
                size: compact ? 28 : 64,
                color: const Color(0xFF059669),
              ),
            ),
          ),
          // Balises clignotantes
          if (!compact)
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (i) {
                  final active = ((t * 4).floor() == i);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? const Color(0xFF34D399) : const Color(0xFF059669).withValues(alpha: 0.3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. DÉDOUANEMENT : Sceau officiel douanier qui tamponne avec impact & bouclier
// ============================================================================
class _AnimPhase7Dedouanement extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase7Dedouanement({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    // Effet d'impact périodique du marteau / tampon douanier
    final impact = (math.sin(t * 2 * math.pi) > 0.7) ? 1.12 : 1.0;
    final rotationMarteau = math.sin(t * 2 * math.pi) * 0.35;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bouclier de conformité douanière
          Container(
            width: compact ? 36 : 90,
            height: compact ? 36 : 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.shield_outlined,
              size: compact ? 26 : 60,
              color: const Color(0xFFDC2626).withValues(alpha: 0.6),
            ),
          ),
          // Marteau de justice / douane qui frappe
          Transform.scale(
            scale: impact,
            child: Transform.rotate(
              angle: rotationMarteau,
              child: Icon(
                Icons.gavel_rounded,
                size: compact ? 22 : 48,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
          // Badge "DOUANE"
          if (!compact)
            Positioned(
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "DOUANE",
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 8. CENTRE DE TRI DESTINATION : Dispatching avec flèches multidirectionnelles
// ============================================================================
class _AnimPhase8CentreTri extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase8CentreTri({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    final pulse = 1.0 + 0.08 * math.sin(t * 2 * math.pi);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Entrepôt central
          Transform.scale(
            scale: pulse,
            child: Icon(
              Icons.warehouse_rounded,
              size: compact ? 26 : 58,
              color: const Color(0xFFEA580C),
            ),
          ),
          // Flèches divergentes vers les points de distribution
          if (!compact) ...[
            Positioned(
              left: 12 + math.sin(t * 2 * math.pi) * 3,
              child: const Icon(Icons.arrow_left_rounded, size: 24, color: Color(0xFFFB923C)),
            ),
            Positioned(
              right: 12 + math.sin(t * 2 * math.pi) * 3,
              child: const Icon(Icons.arrow_right_rounded, size: 24, color: Color(0xFFFB923C)),
            ),
            Positioned(
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Bamako Hub",
                  style: TextStyle(color: Color(0xFFEA580C), fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 9. EN LIVRAISON LOCALE / DISPONIBLE AU RETRAIT : Radar GPS pulsant sur relais
// ============================================================================
class _AnimPhase9LivraisonLocale extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase9LivraisonLocale({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    final radarRayon = t * (compact ? 20.0 : 45.0);
    final radarOpacite = (1.0 - t).clamp(0.0, 1.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anneau radar qui s'élargit
          Container(
            width: radarRayon * 2,
            height: radarRayon * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF16A34A).withValues(alpha: radarOpacite * 0.7),
                width: 2,
              ),
            ),
          ),
          // Icône de boutique relais / livreur
          Icon(
            Icons.storefront_rounded,
            size: compact ? 26 : 58,
            color: const Color(0xFF16A34A),
          ),
          // Badge "PIN PRÊT"
          if (!compact)
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 4),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pin, size: 10, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      "PIN PRÊT",
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 10. LIVRÉ / RETIRÉ : Célébration, boîte ouverte, confettis & check vert
// ============================================================================
class _AnimPhase10LivreRetire extends StatelessWidget {
  final AnimationController controller;
  final bool compact;

  const _AnimPhase10LivreRetire({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    final scale = 1.0 + 0.08 * math.sin(t * 2 * math.pi);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo doré de succès
          Container(
            width: compact ? 36 : 95,
            height: compact ? 36 : 95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF15803D).withValues(alpha: 0.12),
            ),
          ),
          // Coche de succès étincelante
          Transform.scale(
            scale: scale,
            child: Icon(
              Icons.check_circle_rounded,
              size: compact ? 28 : 64,
              color: const Color(0xFF15803D),
            ),
          ),
          // Particules d'étoiles flottantes
          if (!compact) ...[
            Positioned(
              top: 14 - math.sin(t * 2 * math.pi) * 4,
              right: 18,
              child: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
            ),
            Positioned(
              bottom: 16 + math.cos(t * 2 * math.pi) * 4,
              left: 18,
              child: const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Peintre personnalisé pour la route animée de la phase 2
class _RouteAnimPainter extends CustomPainter {
  final double decalage;

  _RouteAnimPainter({required this.decalage});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final startX = -(decalage * (dashWidth + dashSpace));

    for (double x = startX; x < size.width; x += dashWidth + dashSpace) {
      if (x + dashWidth > 0 && x < size.width) {
        canvas.drawLine(
          Offset(math.max(0, x), size.height / 2),
          Offset(math.min(size.width, x + dashWidth), size.height / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RouteAnimPainter oldDelegate) =>
      oldDelegate.decalage != decalage;
}
