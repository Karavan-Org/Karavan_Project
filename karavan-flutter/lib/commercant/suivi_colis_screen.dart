import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/logistique_api_service.dart';
import '../services/api/api_exception.dart';
import '../services/itineraire_service.dart';
import '../widgets/animations_suivi_international.dart';
import '../widgets/image_produit.dart';
import '../widgets/itineraire_depot.dart';
import 'code_retrait_commercant_screen.dart';

/// Écran complet de Suivi de Colis International pour le Commerçant connecté à l'API Karavan.
/// Prend en compte les 10 grandes phases communes à tous les colis internationaux,
/// avec une animation dédiée qui boucle en continu pendant toute la durée de la phase active
/// et la localisation interactive en direct du dépôt / entrepôt via OpenStreetMap & Leaflet.
class SuiviColisScreen extends StatefulWidget {
  final int? commandeIdSelectionnee;
  final int? phaseInitiale;
  final String? initialDepotNom;
  final String? initialDepotAdresse;
  final String? initialLienMaps;

  const SuiviColisScreen({
    super.key,
    this.commandeIdSelectionnee,
    this.phaseInitiale,
    this.initialDepotNom,
    this.initialDepotAdresse,
    this.initialLienMaps,
  });

  @override
  State<SuiviColisScreen> createState() => _SuiviColisScreenState();
}

class _SuiviColisScreenState extends State<SuiviColisScreen> {
  bool _chargement = true;
  String? _erreur;
  List<Map<String, dynamic>> _commandes = [];
  List<Map<String, dynamic>> _participations = [];
  List<Map<String, dynamic>> _convois = [];
  int _indexCommandeSelectionnee = 0;

  /// Phase active sélectionnée (1 à 10)
  int _phaseActive = 5; // En transit international par défaut
  bool _modeSimulation = false;
  LatLng _depotLatLng = const LatLng(12.6392, -7.9982); // Dabanani, Bamako par défaut

  @override
  void initState() {
    super.initState();
    if (widget.phaseInitiale != null) {
      _phaseActive = widget.phaseInitiale!.clamp(1, 10);
      _modeSimulation = true;
    }
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final logistique = LogistiqueApiService.instance;
      final resultats = await Future.wait([
        logistique.mesCommandes(),
        logistique.mesParticipations(),
        logistique.convois(),
      ]);

      if (!mounted) return;
      final cmds = resultats[0];
      final parts = resultats[1];
      final cnvs = resultats[2];

      int idx = 0;
      if (widget.commandeIdSelectionnee != null && cmds.isNotEmpty) {
        final pos = cmds.indexWhere((c) => c['id'] == widget.commandeIdSelectionnee);
        if (pos != -1) idx = pos;
      }

      final Map<String, dynamic>? cmdActive = cmds.isNotEmpty ? cmds[idx.clamp(0, cmds.length - 1)] : null;
      final longGroupeId = cmdActive?['groupeId'];
      final Map<String, dynamic>? convoi = cnvs.where((c) => c['groupeId'] == longGroupeId).firstOrNull;

      int phaseCalculee = _calculerPhaseAutomatique(cmdActive, convoi);
      if (widget.phaseInitiale != null) {
        phaseCalculee = widget.phaseInitiale!.clamp(1, 10);
      }

      setState(() {
        _commandes = cmds;
        _participations = parts;
        _convois = cnvs;
        _indexCommandeSelectionnee = idx;
        if (!_modeSimulation) {
          _phaseActive = phaseCalculee;
        }
        _chargement = false;
      });

      _resoudrePositionDepot(cmdActive);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : "Erreur de chargement des commandes.";
        _chargement = false;
      });
    }
  }

  Future<void> _resoudrePositionDepot(Map<String, dynamic>? cmdActive) async {
    final point = cmdActive?['pointRetrait'] as Map<String, dynamic>?;
    final lien = widget.initialLienMaps ?? point?['lienGoogleMap']?.toString();
    final adr = widget.initialDepotAdresse ?? point?['adresse']?.toString() ?? "Dabanani, Bamako, Mali";

    if (point != null && point['latitude'] is num && point['longitude'] is num) {
      final lat = (point['latitude'] as num).toDouble();
      final lng = (point['longitude'] as num).toDouble();
      if (lat != 0.0 || lng != 0.0) {
        if (mounted) {
          setState(() {
            _depotLatLng = LatLng(lat, lng);
          });
        }
        return;
      }
    }

    try {
      final pos = await ItineraireService.localiserDepot(lien: lien, adresse: adr);
      if (pos != null && mounted) {
        setState(() {
          _depotLatLng = pos;
        });
      }
    } catch (_) {}
  }

  /// Déduit la phase logistique (1 à 10) depuis l'état réel de la commande et du convoi
  int _calculerPhaseAutomatique(Map<String, dynamic>? cmd, Map<String, dynamic>? convoi) {
    if (cmd == null) return 1;

    final statut = cmd['statut']?.toString() ?? 'CREEE';
    final convoiStatut = convoi?['statut']?.toString() ?? '';

    switch (statut) {
      case 'COLLECTEE':
        return 10; // Livré / retiré
      case 'EN_ATTENTE_RETRAIT':
        return 9; // En livraison locale / disponible au retrait
      case 'ARRIVEE':
        return 8; // Centre de tri du pays de destination
      case 'EXPEDIEE':
        if (convoiStatut == 'BLOQUE_DOUANE') return 7; // Dédouanement / blocage
        if (convoiStatut == 'ARRIVE_PORT' || convoiStatut == 'ARRIVE') return 6; // Arrivée dans pays destination
        if (convoiStatut == 'EN_TRANSIT') return 5; // En transit international
        if (convoiStatut == 'ACHETE') return 4; // Départ du pays d'origine
        return 5;
      case 'PREPAREE':
        return 3; // Centre de départ (tri & regroupement)
      case 'EN_PREPARATION':
        return 2; // Expédié par le vendeur / pris en charge
      case 'CREEE':
      default:
        return 1; // Commande reçue / en traitement
    }
  }

  void _changerPhase(int p) {
    setState(() {
      _phaseActive = p.clamp(1, 10);
      _modeSimulation = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    final phaseCourante = PhaseColisInternational.depuisNumero(_phaseActive);

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Suivi de Colis",
              style: TextStyle(
                fontFamily: AppTheme.policeTitre,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.couleurTexte(context),
              ),
            ),
            const Text(
              "Acheminement international en temps réel",
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: AppTheme.couleurCarte(context),
        foregroundColor: AppTheme.couleurTexte(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualiser",
            onPressed: () {
              _modeSimulation = false;
              _charger();
            },
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _erreur != null
              ? _vueErreur()
              : (_commandes.isEmpty && _participations.isEmpty && !_modeSimulation && widget.phaseInitiale == null && widget.initialDepotNom == null)
                  ? _vueAucunColis()
                  : _vueContenu(phaseCourante, estSombre),
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFC0392B)),
            const SizedBox(height: 14),
            Text(_erreur!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _charger, child: const Text("Réessayer")),
          ],
        ),
      ),
    );
  }

  Widget _vueAucunColis() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_outlined, size: 46, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              "Aucun colis actif",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              "Rejoignez un groupe d'achat pour suivre l'acheminement de vos commandes internationales étape par étape.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => setState(() => _modeSimulation = true),
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text("Voir les 10 phases & la carte du dépôt"),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueContenu(PhaseColisInternational phaseCourante, bool estSombre) {
    final Map<String, dynamic>? commande =
        _commandes.isNotEmpty ? _commandes[_indexCommandeSelectionnee.clamp(0, _commandes.length - 1)] : null;
    final longGroupeId = commande?['groupeId'] ?? (_participations.isNotEmpty ? _participations.first['groupeId'] : 1);
    final convoi = _convois.where((c) => c['groupeId'] == longGroupeId).firstOrNull;
    final transporteur = convoi?['transporteur']?.toString();
    final point = commande?['pointRetrait'] as Map<String, dynamic>?;
    final nomPoint = point != null
        ? [point['nom'], point['quartier']].where((s) => s != null && "$s".isNotEmpty).join(" • ")
        : "Point de retrait Karavan (Dabanani, Bamako)";
    final String photoUrl = commande?['photoUrl']?.toString() ?? '';
    final String produit = commande?['produit']?.toString() ?? 'Commande groupée internationale';
    final int commandeId = (commande?['id'] as num?)?.toInt() ?? 11;
    final String numeroSuivi = "TR-BKO-${commandeId.toString().padLeft(2, '0')}-INTL";
    final int progressionPourcentage = ((_phaseActive / 10) * 100).round();
    final bool peutRetirer = _phaseActive >= 9;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CARTE COMMANDE SÉLECTIONNÉE
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.couleurBordure(context)),
              boxShadow: const [
                BoxShadow(color: Color(0x082C241E), blurRadius: 14, offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 58,
                    height: 58,
                    color: AppTheme.couleurSurfaceDouce(context),
                    padding: const EdgeInsets.all(4),
                    child: imageProduit(
                      photoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.inventory_2_outlined,
                        size: 30,
                        color: AppTheme.textePale,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B4026).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "#$numeroSuivi",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7B4026),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: phaseCourante.couleur.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Phase $_phaseActive/10",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: phaseCourante.couleur,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        produit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.couleurTexte(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Groupe #$longGroupeId • $nomPoint",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
                      ),
                      if (transporteur != null && transporteur.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Transporteur : $transporteur",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. HERO CARD D'ANIMATION DE LA PHASE EN COURS (Vitrine animée dynamique)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 12,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: phaseCourante.couleur.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: phaseCourante.couleur.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: phaseCourante.couleur,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "PHASE ACTIVE",
                            style: TextStyle(
                              color: phaseCourante.couleur,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "$progressionPourcentage %",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ANIMATION CENTRALE CONTINUE REPRÉSENTANT LA PHASE
                AnimationPhaseWidget(
                  key: ValueKey(_phaseActive),
                  numeroPhase: _phaseActive,
                  compact: false,
                  taille: 120,
                ),

                const SizedBox(height: 12),
                Text(
                  phaseCourante.titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phaseCourante.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        phaseCourante.lieuTypique,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Jauge horizontale de progression (10 crans)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _phaseActive / 10,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(phaseCourante.couleur),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. CARTE ET LOCALISATION DU DÉPÔT / ENTREPÔT (Leaflet & OpenStreetMap)
          _buildSectionCarteDepot(
            context: context,
            commande: commande,
            estArriveeOuRetrait: _phaseActive >= 8,
          ),

          // 4. BARRE DE NAVIGATION RAPIDE PARMI LES 10 PHASES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Les 10 phases internationales",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.couleurTexte(context),
                  ),
                ),
              ),
              if (_modeSimulation) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _modeSimulation = false);
                    _charger();
                  },
                  child: const Text(
                    "Revenir au direct",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Sélecteur horizontal des 10 phases pour tester et animer facilement
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: PhaseColisInternational.toutes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final p = PhaseColisInternational.toutes[i];
                final estSelectionnee = p.numero == _phaseActive;
                return ChoiceChip(
                  label: Text("${p.numero}. ${p.titre.split(' / ').first}"),
                  selected: estSelectionnee,
                  selectedColor: p.couleur,
                  backgroundColor: AppTheme.couleurCarte(context),
                  labelStyle: TextStyle(
                    color: estSelectionnee ? Colors.white : AppTheme.couleurTexte(context),
                    fontSize: 12,
                    fontWeight: estSelectionnee ? FontWeight.w800 : FontWeight.w600,
                  ),
                  onSelected: (val) {
                    if (val) _changerPhase(p.numero);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 4. CHRONOLOGIE VERTICALE COMPLÈTE AVEC ANIMATION DANS LA PHASE ACTIVE
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.couleurBordure(context)),
              boxShadow: const [
                BoxShadow(color: Color(0x062C241E), blurRadius: 14, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(PhaseColisInternational.toutes.length, (index) {
                final phase = PhaseColisInternational.toutes[index];
                final estPasse = phase.numero < _phaseActive;
                final estActuelle = phase.numero == _phaseActive;
                final estDerniere = index == PhaseColisInternational.toutes.length - 1;

                return _buildLigneEtape(
                  phase: phase,
                  estPasse: estPasse,
                  estActuelle: estActuelle,
                  estDerniere: estDerniere,
                );
              }),
            ),
          ),

          const SizedBox(height: 20),

          // 5. BOUTON D'ACTION SELON L'ÉTAT DU COLIS
          if (peutRetirer)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CodeRetraitCommercantScreen(
                        codeCommande: commandeId.toString(),
                        nomProduit: produit,
                        quantite: (commande?['quantite'] as num?)?.toInt() ?? 1,
                        pointRetrait: nomPoint,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 22),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Voir mon code de retrait (QR)",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCarteDepot({
    required BuildContext context,
    required Map<String, dynamic>? commande,
    required bool estArriveeOuRetrait,
  }) {
    final point = commande?['pointRetrait'] as Map<String, dynamic>?;
    final String nomDepot = widget.initialDepotNom ??
        point?['nom']?.toString() ??
        "Dépôt Central Karavan (Dabanani)";
    final String adresseDepot = widget.initialDepotAdresse ??
        point?['adresse']?.toString() ??
        "Grand Marché, Dabanani, Bamako";
    final String lienMaps = widget.initialLienMaps ??
        point?['lienGoogleMap']?.toString() ??
        "https://maps.google.com/?q=${_depotLatLng.latitude},${_depotLatLng.longitude}";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: estArriveeOuRetrait ? AppTheme.primary.withValues(alpha: 0.5) : AppTheme.couleurBordure(context),
          width: estArriveeOuRetrait ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: estArriveeOuRetrait ? AppTheme.primary.withValues(alpha: 0.08) : const Color(0x062C241E),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du dépôt
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: estArriveeOuRetrait
                        ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                        : AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    estArriveeOuRetrait ? Icons.store_mall_directory_rounded : Icons.location_on_rounded,
                    color: estArriveeOuRetrait ? const Color(0xFF16A34A) : AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nomDepot,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.couleurTexte(context),
                              ),
                            ),
                          ),
                          if (estArriveeOuRetrait)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Arrivé au dépôt",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        adresseDepot,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.couleurTexteAttenue(context),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Carte OpenStreetMap Leaflet interactive intégrée
          Container(
            height: 190,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.couleurBordure(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _depotLatLng,
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.karavan_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _depotLatLng,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.warehouse_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Badge "OpenStreetMap" discret
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "OpenStreetMap · Leaflet",
                      style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Bouton "Agrandir"
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        afficherItineraireDepot(
                          context,
                          nomDepot: nomDepot,
                          adresse: adresseDepot,
                          lienGoogleMaps: lienMaps,
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen_rounded, size: 16, color: AppTheme.terre),
                            SizedBox(width: 4),
                            Text(
                              "Agrandir",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.terre),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barre d'actions sous la carte
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      afficherItineraireDepot(
                        context,
                        nomDepot: nomDepot,
                        adresse: adresseDepot,
                        lienGoogleMaps: lienMaps,
                      );
                    },
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("Itinéraire GPS vers le dépôt"),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (lienMaps.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => launchUrl(Uri.parse(lienMaps), mode: LaunchMode.externalApplication),
                    tooltip: "Ouvrir dans Google Maps",
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.couleurSurfaceDouce(context),
                      foregroundColor: AppTheme.couleurTexte(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppTheme.couleurBordure(context)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLigneEtape({
    required PhaseColisInternational phase,
    required bool estPasse,
    required bool estActuelle,
    required bool estDerniere,
  }) {
    Color couleurPastille;
    if (estPasse) {
      couleurPastille = const Color(0xFF16A34A); // Vert terminé
    } else if (estActuelle) {
      couleurPastille = phase.couleur; // Couleur vive de la phase
    } else {
      couleurPastille = const Color(0xFFCBD5E1); // Gris neutre
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne indicateur vertical
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: estActuelle
                    ? phase.couleur.withValues(alpha: 0.2)
                    : (estPasse ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: couleurPastille,
                  width: estActuelle ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: estPasse
                    ? const Icon(Icons.check, size: 18, color: Color(0xFF16A34A))
                    : Icon(phase.icone, size: 18, color: couleurPastille),
              ),
            ),
            if (!estDerniere)
              Container(
                width: 2.5,
                height: estActuelle ? 80 : 42,
                color: estPasse ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Détails de la phase
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => _changerPhase(phase.numero),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: estActuelle ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(vertical: 4),
                decoration: estActuelle
                    ? BoxDecoration(
                        color: phase.couleur.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: phase.couleur.withValues(alpha: 0.35), width: 1.2),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${phase.numero}. ${phase.titre}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: estActuelle ? FontWeight.w900 : (estPasse ? FontWeight.w700 : FontWeight.w600),
                              color: estActuelle
                                  ? phase.couleur
                                  : (estPasse ? AppTheme.couleurTexte(context) : AppTheme.couleurTexteAttenue(context)),
                            ),
                          ),
                        ),
                        if (estActuelle)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: phase.couleur,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "En cours",
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phase.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: estActuelle ? AppTheme.couleurTexte(context) : AppTheme.couleurTexteAttenue(context),
                        height: 1.3,
                      ),
                    ),

                    // Si la phase est active : on intègre l'animation compacte dédiée
                    if (estActuelle) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6),
                              ],
                            ),
                            child: AnimationPhaseWidget(
                              numeroPhase: phase.numero,
                              compact: true,
                              taille: 44,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              phase.sousTitre,
                              style: TextStyle(
                                fontSize: 11,
                                color: phase.couleur.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
