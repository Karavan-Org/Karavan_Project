import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/logistique_api_service.dart';
import '../services/api/api_exception.dart';
import 'code_retrait_commercant_screen.dart';

/// Écran complet de Suivi de Colis pour le Commerçant connecté à l'API DoGo.
/// Affiche la progression réelle de la participation, le statut de la commande,
/// et les jalons du convoi logistique (RG-44 à RG-56).
class SuiviColisScreen extends StatefulWidget {
  final int? commandeIdSelectionnee;

  const SuiviColisScreen({super.key, this.commandeIdSelectionnee});

  @override
  State<SuiviColisScreen> createState() => _SuiviColisScreenState();
}

class _EtapeReelle {
  final int index;
  final String titre;
  final String description;
  final bool atteinte;
  final bool enCours;
  final IconData icone;

  const _EtapeReelle({
    required this.index,
    required this.titre,
    required this.description,
    required this.atteinte,
    required this.enCours,
    required this.icone,
  });
}

class _SuiviColisScreenState extends State<SuiviColisScreen> {
  bool _chargement = true;
  String? _erreur;
  List<Map<String, dynamic>> _commandes = [];
  List<Map<String, dynamic>> _participations = [];
  List<Map<String, dynamic>> _convois = [];
  int _indexCommandeSelectionnee = 0;

  @override
  void initState() {
    super.initState();
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

      setState(() {
        _commandes = cmds;
        _participations = parts;
        _convois = cnvs;
        _indexCommandeSelectionnee = idx;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : "Erreur de chargement des commandes.";
        _chargement = false;
      });
    }
  }

  String _formaterDate(dynamic val) {
    if (val == null) return '';
    final dt = DateTime.tryParse(val.toString())?.toLocal();
    if (dt == null) return '';
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  static String _libelleStatutConvoi(String s) => switch (s) {
        'ACHETE' => 'Marchandises achetées',
        'CHEZ_TRANSITAIRE' => 'Chez le transitaire',
        'EN_TRANSIT' => 'En transit international',
        'BLOQUE_DOUANE' => 'En contrôle douanier',
        'ARRIVE' => 'Arrivé à destination',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Suivi de Mon Colis",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            tooltip: "Actualiser",
            onPressed: _charger,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? Center(
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
                )
              : _commandes.isEmpty && _participations.isEmpty
                  ? _vueAucunColis()
                  : _vueContenu(),
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
              "Aucun colis en cours",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "Rejoignez un groupe d'achat pour suivre l'acheminement de vos commandes en temps réel.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueContenu() {
    // Si on a des commandes créées, on prend la sélectionnée
    final Map<String, dynamic>? commande =
        _commandes.isNotEmpty ? _commandes[_indexCommandeSelectionnee.clamp(0, _commandes.length - 1)] : null;

    final longGroupeId = commande?['groupeId'] ?? (_participations.isNotEmpty ? _participations.first['groupeId'] : null);

    // Trouver le convoi associé au groupe de la commande
    final convoi = _convois.where((c) => c['groupeId'] == longGroupeId).firstOrNull;

    // Statut commande: CREEE, PREPAREE, EXPEDIEE, ARRIVEE, EN_ATTENTE_RETRAIT, COLLECTEE
    final statutCmd = commande?['statut']?.toString() ?? 'EN_ATTENTE_GROUPE';
    final point = commande?['pointRetrait'] as Map<String, dynamic>?;
    final nomPoint = point != null ? [point['nom'], point['quartier']].where((s) => s != null && "$s".isNotEmpty).join(" • ") : "Point de retrait à confirmer";

    // Calcul des étapes réelles
    final etapes = _calculerEtapesReelles(commande, convoi);
    final etapeCourante = etapes.lastWhere((e) => e.atteinte, orElse: () => etapes.first);
    final etapesAtteintes = etapes.where((e) => e.atteinte).length;
    final pct = ((etapesAtteintes / etapes.length) * 100).round();
    final peutRetirer = statutCmd == 'EN_ATTENTE_RETRAIT' || statutCmd == 'ARRIVEE' || statutCmd == 'COLLECTEE';

    return RefreshIndicator(
      onRefresh: _charger,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélecteur de commande si multiple
            if (_commandes.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_commandes.length, (i) {
                    final c = _commandes[i];
                    final estActive = i == _indexCommandeSelectionnee;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 12),
                      child: ChoiceChip(
                        label: Text("Commande n°${c['id']} • ${c['produit'] ?? ''}"),
                        selected: estActive,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: estActive ? Colors.white : AppTheme.textPrimary,
                          fontWeight: estActive ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _indexCommandeSelectionnee = i);
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // 1. CARTE RÉCAPITULATIVE DU COLIS
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Color(0x0C46321E), blurRadius: 18, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, size: 38, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Groupe n°$longGroupeId",
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF996B00),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: peutRetirer
                                    ? AppTheme.success.withValues(alpha: 0.15)
                                    : AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statutCmd,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: peutRetirer ? AppTheme.success : AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          commande?['produit']?.toString() ?? "Commande groupée",
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Commande n°${commande?['id'] ?? '—'} • ${commande?['quantite'] ?? 1} unité(s)",
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                        ),
                        if (point != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            "Point : $nomPoint",
                            style: const TextStyle(fontSize: 11, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. JAUGE D'AVANCEMENT EN TEMPS RÉEL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF8A5F3E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(color: Color(0x2446321E), blurRadius: 20, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "Étape ${etapeCourante.index} sur ${etapes.length}",
                                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              etapeCourante.titre,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "$pct%",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: etapesAtteintes / etapes.length,
                      minHeight: 12,
                      backgroundColor: Colors.black.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                    ),
                  ),
                ],
              ),
            ),

            // Événements logistiques détaillés du convoi si disponibles
            if (convoi != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Convoi ${convoi['reference']} • ${_libelleStatutConvoi(convoi['statut'] ?? '')}",
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    if (convoi['transporteur'] != null && "${convoi['transporteur']}".isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text("Transporteur : ${convoi['transporteur']}", style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                    if (convoi['evenements'] is List && (convoi['evenements'] as List).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      ...((convoi['evenements'] as List).cast<Map<String, dynamic>>().reversed.map((ev) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.circle, size: 7, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${ev['statut']} — ${ev['localisation']}",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(_formaterDate(ev['date']), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        );
                      })),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 4. CHRONOLOGIE DES ÉTAPES DU CYCLE
            Text(
              "Parcours logistique réel (${etapes.length} étapes)",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),

            ...etapes.map((etape) => _buildLigneChronologie(etape, etape.index == etapes.length)),

            const SizedBox(height: 24),

            // 5. ACTION RETIRER LE COLIS
            ElevatedButton.icon(
              onPressed: peutRetirer && commande != null
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CodeRetraitCommercantScreen(
                            codeCommande: commande['id']?.toString() ?? '',
                            nomProduit: commande['produit']?.toString() ?? 'Commande groupée',
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.qr_code, size: 22),
              label: Text(
                peutRetirer ? "Retirer mon colis (QR Code & PIN)" : "Retrait disponible à l'arrivée",
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: peutRetirer ? AppTheme.success : Colors.grey.shade400,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<_EtapeReelle> _calculerEtapesReelles(Map<String, dynamic>? cmd, Map<String, dynamic>? cnv) {
    final statutCmd = cmd?['statut']?.toString();
    final statutCnv = cnv?['statut']?.toString();

    final cmdCreee = cmd != null;
    final cmdPreparee = const {'PREPAREE', 'EXPEDIEE', 'ARRIVEE', 'EN_ATTENTE_RETRAIT', 'COLLECTEE'}.contains(statutCmd);
    final cmdExpediee = const {'EXPEDIEE', 'ARRIVEE', 'EN_ATTENTE_RETRAIT', 'COLLECTEE'}.contains(statutCmd) ||
        const {'EN_TRANSIT', 'BLOQUE_DOUANE', 'ARRIVE'}.contains(statutCnv);
    final cmdArrivee = const {'ARRIVEE', 'EN_ATTENTE_RETRAIT', 'COLLECTEE'}.contains(statutCmd) || statutCnv == 'ARRIVE';
    final cmdAuPoint = const {'EN_ATTENTE_RETRAIT', 'COLLECTEE'}.contains(statutCmd);
    final cmdCollectee = statutCmd == 'COLLECTEE';

    return [
      _EtapeReelle(
        index: 1,
        titre: "Participation confirmée",
        description: "Paiement validé et sécurisé sous séquestre DoGo.",
        atteinte: true,
        enCours: !cmdCreee,
        icone: Icons.verified_user_outlined,
      ),
      _EtapeReelle(
        index: 2,
        titre: "Objectif atteint & Commande créée",
        description: "Le groupe a atteint son quota cible d'acheteurs.",
        atteinte: cmdCreee,
        enCours: cmdCreee && !cmdPreparee,
        icone: Icons.check_circle_outline,
      ),
      _EtapeReelle(
        index: 3,
        titre: "Conditionnement par le fournisseur",
        description: "Vérification des lots et préparation des colis.",
        atteinte: cmdPreparee,
        enCours: cmdPreparee && !cmdExpediee,
        icone: Icons.inventory_2_outlined,
      ),
      _EtapeReelle(
        index: 4,
        titre: "Expédition & Acheminement international",
        description: cnv != null
            ? "Convoi ${cnv['reference']} : ${_libelleStatutConvoi(cnv['statut'] ?? '')}"
            : "Colis pris en charge par le transporteur.",
        atteinte: cmdExpediee,
        enCours: cmdExpediee && !cmdArrivee,
        icone: Icons.local_shipping_outlined,
      ),
      _EtapeReelle(
        index: 5,
        titre: "Dédouanement et dépôt central",
        description: "Validation administrative et contrôle d'arrivée au hub DoGo.",
        atteinte: cmdArrivee,
        enCours: cmdArrivee && !cmdAuPoint,
        icone: Icons.warehouse_outlined,
      ),
      _EtapeReelle(
        index: 6,
        titre: "Disponible au point de retrait",
        description: "Colis déposé au relais. Code PIN et QR Code débloqués.",
        atteinte: cmdAuPoint,
        enCours: cmdAuPoint && !cmdCollectee,
        icone: Icons.storefront_outlined,
      ),
      _EtapeReelle(
        index: 7,
        titre: "Colis retiré",
        description: "Retrait validé avec succès auprès du magasinier.",
        atteinte: cmdCollectee,
        enCours: false,
        icone: Icons.task_alt_rounded,
      ),
    ];
  }

  Widget _buildLigneChronologie(_EtapeReelle etape, bool estDerniere) {
    Color pointColor;
    if (etape.atteinte && !etape.enCours) {
      pointColor = AppTheme.success;
    } else if (etape.enCours) {
      pointColor = AppTheme.secondary;
    } else {
      pointColor = const Color(0xFFD6CBC0);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: pointColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: pointColor, width: 2),
              ),
              child: Icon(
                etape.atteinte && !etape.enCours ? Icons.check : etape.icone,
                size: 18,
                color: pointColor,
              ),
            ),
            if (!estDerniere)
              Container(
                width: 2.5,
                height: 52,
                color: etape.atteinte && !etape.enCours ? AppTheme.success : const Color(0xFFE2D8CF),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        etape.titre,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: etape.atteinte ? FontWeight.w800 : FontWeight.w600,
                          color: etape.atteinte ? AppTheme.textPrimary : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    if (etape.enCours)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "En cours",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF8A5F00)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  etape.description,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
