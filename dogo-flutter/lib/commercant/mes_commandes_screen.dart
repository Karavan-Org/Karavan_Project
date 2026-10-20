import '../widgets/tab_navigation_scope.dart';
import 'package:flutter/material.dart';
import '../models/participation_model.dart';
import '../models/remboursement_model.dart';
import '../services/groupe_api_service.dart';
import '../services/logistique_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_popups.dart';
import 'code_retrait_commercant_screen.dart';

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
    if (lower.contains('chaussure') || lower.contains('basket') || lower.contains('sneaker')) {
      return 'assets/images/Nike_Joyride-removebg-preview.png';
    }
    if (lower.contains('montre') || lower.contains('accessoire')) {
      return 'assets/images/logo_karavan.png';
    }
    return 'assets/images/Nike_Joyride-removebg-preview.png';
  }

  factory ElementCommande.fromParticipation(ParticipationModel p, {RemboursementModel? remboursement}) {
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

  factory ElementCommande.fromCommande(Map<String, dynamic> c) {
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

/// Écran "Mes commandes" conforme au modèle Figma exact
/// Présente :
/// 1. La liste des commandes et participations réelles avec visuels, détails et bouton "Annuler"
/// 2. Le stepper de suivi d'étapes (Achat effectué, Chez le transitaire, En transit, Arrivée à Bamako, Disponible au retrait)
/// 3. La carte d'illustration du trajet maritime (Chine 📍 ---> 🚢 Cargo ---> 📍 Bamako)
/// 4. La bannière flottante de statut avec gestion du code de retrait et du remboursement
class MesCommandesScreen extends StatefulWidget {
  const MesCommandesScreen({super.key});

  @override
  State<MesCommandesScreen> createState() => _MesCommandesScreenState();
}

class _MesCommandesScreenState extends State<MesCommandesScreen> {
  int _selectedOrderIndex = 0;
  bool _isLoading = true;
  bool _annulationEnCours = false;
  String? _errorMessage;
  final List<ElementCommande> _commandes = [];

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait([
        GroupeApiService.instance.mesParticipations(),
        LogistiqueApiService.instance.mesCommandes(),
        GroupeApiService.instance.mesRemboursements(),
      ]);

      final participations = futures[0] as List<ParticipationModel>;
      final commandesLogistiques = futures[1] as List<Map<String, dynamic>>;
      final remboursements = futures[2] as List<RemboursementModel>;

      // Map des remboursements par ID de participation
      final rembParPartId = <int, RemboursementModel>{};
      for (final r in remboursements) {
        if (r.participationId != null) {
          rembParPartId[r.participationId!] = r;
        }
      }

      // Récupérer les identifiants des participations déjà converties en commandes
      final partIdsDejaEnCommandes = commandesLogistiques
          .map((c) => (c['participationId'] as num?)?.toInt())
          .whereType<int>()
          .toSet();

      final elements = <ElementCommande>[];

      // 1. Ajouter d'abord les commandes logistiques réelles (statut avancé)
      for (final c in commandesLogistiques) {
        elements.add(ElementCommande.fromCommande(c));
      }

      // 2. Ajouter les participations qui ne sont pas encore devenues des commandes logistiques
      for (final p in participations) {
        if (!partIdsDejaEnCommandes.contains(p.id)) {
          final remb = rembParPartId[p.id];
          elements.add(ElementCommande.fromParticipation(p, remboursement: remb));
        }
      }

      // Trier : éléments récents en premier
      elements.sort((a, b) {
        if (a.dateCreation != null && b.dateCreation != null) {
          return b.dateCreation!.compareTo(a.dateCreation!);
        }
        return b.id.compareTo(a.id);
      });

      if (mounted) {
        setState(() {
          _commandes.clear();
          _commandes.addAll(elements);
          if (_selectedOrderIndex >= _commandes.length) {
            _selectedOrderIndex = 0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible de charger vos commandes : $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _annulerCommande(ElementCommande item) async {
    if (_annulationEnCours) return;
    final bool estPaye = item.payee;
    final String montantTexte = '${item.montant.toStringAsFixed(0)} FCFA';

    final bool? confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_outlined, color: Color(0xFFE53935), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                estPaye ? "Demande de remboursement" : "Annuler la réservation",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Souhaitez-vous annuler votre participation à « ${item.titre} » (${item.quantite} unité${item.quantite > 1 ? 's' : ''}) ?",
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (estPaye)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Sécurité & Garantie Karavan (RG-31) :",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "• L'annulation n'est autorisée qu'avant les 100% du quota du groupe.\n"
                      "• Une notification est transmise immédiatement à l'administrateur.\n"
                      "• Le montant intégral de $montantTexte sera restitué sur votre compte Mobile Money dès validation.",
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF14532D),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE0B2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Votre réservation de quota sera immédiatement libérée pour les autres commerçants.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFBF360C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Retour", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(estPaye ? "Confirmer le remboursement" : "Confirmer l'annulation"),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    setState(() => _annulationEnCours = true);

    try {
      if (item.estParticipation && item.participationId != null) {
        await GroupeApiService.instance.annulerParticipation(item.participationId);
      }
      if (mounted) {
        await AppPopups.afficher(
          context: context,
          titre: estPaye ? "Demande de remboursement transmise" : "Réservation annulée",
          message: estPaye
              ? "Votre demande d'annulation et de remboursement de $montantTexte a été enregistrée avec succès."
              : "Votre réservation a été annulée. Votre quota a été libéré pour les autres commerçants.",
          detailSupplementaire: estPaye
              ? "Dès validation par l'administration Karavan, les fonds seront automatiquement recrédités sur votre Portefeuille Achats."
              : null,
          icone: Icons.check_circle_outline_rounded,
          couleurIcone: const Color(0xFF2E7D32),
          couleurFondIcone: const Color(0xFFE8F5E9),
          boutonTexte: "Fermer et continuer",
          onFermer: () => _chargerDonnees(),
        );
      }
    } catch (e) {
      if (mounted) {
        await AppPopups.traiterErreurOuConflit(
          context,
          e,
          onFermer: () {
            if (mounted) _chargerDonnees();
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _annulationEnCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // Fond doux Design System
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context), size: 22),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),
        titleSpacing: 0,
        title: const Text(
          "Mes commandes",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E1E1E), size: 22),
            onPressed: _isLoading ? null : _chargerDonnees,
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _commandes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_errorMessage != null && _commandes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _chargerDonnees,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    if (_commandes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _chargerDonnees,
        color: AppTheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
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
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 46,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Aucune commande active",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Rejoignez un groupe d'achat pour passer votre première commande groupée.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final activeCmd = _commandes[_selectedOrderIndex.clamp(0, _commandes.length - 1)];

    return RefreshIndicator(
      onRefresh: _chargerDonnees,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. LISTE DES CARTES DE COMMANDES (Figma Top Cards)
            for (int i = 0; i < _commandes.length; i++) ...[
              _buildOrderCard(i),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            // 2. CARTE BLANCHE DE SUIVI : LE STEPPER VERTICAL FIGMA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEFE8DD), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A46321E),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepRow(
                    stepIndex: 0,
                    currentActiveStep: activeCmd.etapeActive,
                    title: activeCmd.annulee ? "Participation annulée" : "Achat effectué",
                    dateOrSubtitle: activeCmd.annulee
                        ? "Remboursement portefeuille"
                        : (activeCmd.payee ? "Paiement validé • Séquestre" : "Réservation active"),
                    isFirst: true,
                    isAnnulee: activeCmd.annulee,
                  ),
                  _buildConnectingLine(
                    isPassed: activeCmd.etapeActive > 0 && !activeCmd.annulee,
                  ),
                  _buildStepRow(
                    stepIndex: 1,
                    currentActiveStep: activeCmd.etapeActive,
                    title: "Chez le transitaire",
                    dateOrSubtitle: activeCmd.etapeActive >= 1 ? "Validation & Préparation" : null,
                    isPending: activeCmd.etapeActive < 1,
                  ),
                  _buildConnectingLine(
                    isPassed: activeCmd.etapeActive > 1,
                  ),
                  _buildStepRow(
                    stepIndex: 2,
                    currentActiveStep: activeCmd.etapeActive,
                    title: "En transit",
                    dateOrSubtitle: activeCmd.etapeActive == 2
                        ? activeCmd.arriveeEstimee
                        : (activeCmd.etapeActive > 2 ? "Acheminé" : null),
                    isActiveStep: activeCmd.etapeActive == 2,
                    isPending: activeCmd.etapeActive < 2,
                  ),
                  _buildConnectingLine(
                    isPassed: activeCmd.etapeActive > 2,
                    isDashed: true,
                  ),
                  _buildStepRow(
                    stepIndex: 3,
                    currentActiveStep: activeCmd.etapeActive,
                    title: "Arrivée à Bamako",
                    dateOrSubtitle: activeCmd.etapeActive >= 3 ? "Colis réceptionné" : null,
                    isActiveStep: activeCmd.etapeActive == 3,
                    isPending: activeCmd.etapeActive < 3,
                  ),
                  _buildConnectingLine(
                    isPassed: activeCmd.etapeActive > 3,
                    isDashed: true,
                  ),
                  _buildStepRow(
                    stepIndex: 4,
                    currentActiveStep: activeCmd.etapeActive,
                    title: "Disponible au retrait",
                    dateOrSubtitle: activeCmd.etapeActive == 4 ? "Présentez votre QR Code / PIN" : null,
                    isActiveStep: activeCmd.etapeActive == 4,
                    isPending: activeCmd.etapeActive < 4,
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. ILLUSTRATION DU TRAJET MARITIME (Chine 📍 ---> 🚢 ---> 📍 Bamako)
            Container(
              width: double.infinity,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F2F8), // Fond bleu ciel doux Figma
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4E6F2), width: 1.2),
              ),
              child: CustomPaint(
                painter: _MaritimeRoutePainter(
                  departLabel: activeCmd.origine,
                  arriveeLabel: activeCmd.destination,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 4. BANNIÈRE FLOTTANTE DE STATUT : Statut actif & action retrait
            InkWell(
              onTap: () {
                if (activeCmd.etapeActive >= 4 && activeCmd.commandeId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CodeRetraitCommercantScreen(
                        codeCommande: activeCmd.commandeId.toString(),
                        nomProduit: activeCmd.titre,
                        quantite: activeCmd.quantite,
                      ),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: activeCmd.annulee
                      ? (activeCmd.remboursement?.execute == true
                          ? const Color(0xFF16A34A)
                          : (activeCmd.remboursement?.enTraitement == true
                              ? const Color(0xFFD97706)
                              : const Color(0xFFC0392B)))
                      : (activeCmd.etapeActive >= 4 ? const Color(0xFF1EB980) : const Color(0xFF9E6E4B)),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: (activeCmd.annulee
                              ? (activeCmd.remboursement?.execute == true
                                  ? const Color(0xFF16A34A)
                                  : (activeCmd.remboursement?.enTraitement == true
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFC0392B)))
                              : (activeCmd.etapeActive >= 4 ? const Color(0xFF1EB980) : const Color(0xFF9E6E4B)))
                          .withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (activeCmd.etapeActive >= 4 && activeCmd.commandeId != null) ...[
                          const Icon(Icons.qr_code, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            activeCmd.statutLibelle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      activeCmd.arriveeEstimee,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activeCmd.annulee
                            ? (activeCmd.remboursement?.enTraitement == true
                                ? const Color(0xFFFEF3C7)
                                : Colors.white70)
                            : const Color(0xFFFFDFA6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Carte individuelle de commande active (Figma Top Card)
  Widget _buildOrderCard(int index) {
    final cmd = _commandes[index];
    final bool isSelected = _selectedOrderIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _selectedOrderIndex = index);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF9E6E4B) : const Color(0xFFEFE8DD),
            width: isSelected ? 1.6 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0x1A9E6E4B) : const Color(0x0846321E),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Vignette Produit sur fond beige clair
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 62,
                height: 62,
                color: const Color(0xFFF6F0E6),
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  cmd.imageLocale,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.inventory_2_outlined,
                    size: 30,
                    color: Color(0xFF9E6E4B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Détails de la commande
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cmd.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cmd.details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        cmd.numero,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Badge de statut
                      _buildStatutChip(cmd),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Bouton "Annuler" ou indicateur de retrait
            if (cmd.annulee)
              InkWell(
                onTap: () {
                  final String remboursementMsg = cmd.remboursement != null
                      ? (cmd.remboursement!.execute
                          ? "Le montant de ${cmd.remboursement!.montant.toStringAsFixed(0)} FCFA a été restitué avec succès sur votre portefeuille d'achats."
                          : "Votre demande de remboursement de ${cmd.remboursement!.montant.toStringAsFixed(0)} FCFA est actuellement en cours d'examen par l'administration Karavan.")
                      : "Cette commande ou participation a déjà été annulée et prise en compte dans votre espace.";
                  AppPopups.afficherActionDejaEffectuee(
                    context: context,
                    titre: "Commande déjà annulée",
                    message: remboursementMsg,
                    detail: "Aucune action supplémentaire requise de votre part.",
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cmd.remboursement?.enTraitement == true
                        ? const Color(0xFFFEF3C7)
                        : (cmd.remboursement?.execute == true
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cmd.remboursement?.enTraitement == true
                            ? "En cours"
                            : (cmd.remboursement?.execute == true
                                ? "Remboursé"
                                : "Annulé"),
                        style: TextStyle(
                          color: cmd.remboursement?.enTraitement == true
                              ? const Color(0xFFB45309)
                              : (cmd.remboursement?.execute == true
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE53935)),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: cmd.remboursement?.enTraitement == true
                            ? const Color(0xFFB45309)
                            : (cmd.remboursement?.execute == true
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE53935)),
                      ),
                    ],
                  ),
                ),
              )
            else if (cmd.annulable)
              TextButton(
                onPressed: _annulationEnCours ? null : () => _annulerCommande(cmd),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _annulationEnCours
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53935)),
                      )
                    : const Text(
                        "Annuler",
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              )
            else if (!cmd.annulable && !cmd.annulee && cmd.etapeActive < 4)
              InkWell(
                onTap: () {
                  AppPopups.afficherActionImpossible(
                    context: context,
                    titre: "Annulation impossible",
                    message:
                        "Cette commande ne peut plus être annulée car le convoi a atteint son quota ou l'acheminement est déjà engagé.",
                    detail: "Vos articles sont en cours d'expédition et sous garantie séquestre Karavan.",
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "En convoi",
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.lock_outline, size: 12, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              )
            else if (cmd.etapeActive >= 4)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "À retirer",
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutChip(ElementCommande cmd) {
    if (cmd.annulee) {
      if (cmd.remboursement != null) {
        if (cmd.remboursement!.enTraitement) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              "En traitement",
              style: TextStyle(color: Color(0xFFB45309), fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
          );
        } else if (cmd.remboursement!.execute) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              "Remboursé",
              style: TextStyle(color: Color(0xFF2E7D32), fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
          );
        } else if (cmd.remboursement!.rejete) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              "Rejeté",
              style: TextStyle(color: Color(0xFFC0392B), fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
          );
        }
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          "Annulé",
          style: TextStyle(color: Color(0xFFC0392B), fontSize: 9.5, fontWeight: FontWeight.w700),
        ),
      );
    }
    if (cmd.payee) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          "Séquestre actif",
          style: TextStyle(color: Color(0xFF2E7D32), fontSize: 9.5, fontWeight: FontWeight.w700),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        "Réservé",
        style: TextStyle(color: Color(0xFFE65100), fontSize: 9.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Ligne d'une étape de la chronologie (Stepper Figma)
  Widget _buildStepRow({
    required int stepIndex,
    required int currentActiveStep,
    required String title,
    required String? dateOrSubtitle,
    bool isActiveStep = false,
    bool isPending = false,
    bool isFirst = false,
    bool isLast = false,
    bool isAnnulee = false,
  }) {
    final bool isCompleted = stepIndex < currentActiveStep && !isAnnulee;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icône / Pastille circulaire de l'étape
        _buildStepBadge(isCompleted, isActiveStep, isPending, isAnnulee),
        const SizedBox(width: 14),

        // Libellé et sous-titre de l'étape
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: (isActiveStep || isCompleted) ? FontWeight.w800 : FontWeight.w600,
                  color: isAnnulee
                      ? const Color(0xFFC0392B)
                      : (isActiveStep
                          ? const Color(0xFF9E6E4B)
                          : (isCompleted ? const Color(0xFF1E1E1E) : const Color(0xFF6B6B6B))),
                ),
              ),
              if (dateOrSubtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  dateOrSubtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isAnnulee
                        ? const Color(0xFFE53935)
                        : (isActiveStep ? const Color(0xFF8C5F3E) : const Color(0xFF888888)),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Chevron droit '>' si étape validée ou active
        if (!isPending && !isAnnulee)
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: Color(0xFFB0B0B0),
          ),
      ],
    );
  }

  Widget _buildStepBadge(bool isCompleted, bool isActive, bool isPending, bool isAnnulee) {
    if (isAnnulee) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFE53935),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 17, color: Colors.white),
      );
    }
    if (isCompleted) {
      // Pastille verte avec coche blanche
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF1EB980),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 17, color: Colors.white),
      );
    } else if (isActive) {
      // Pastille marron/camel avec icône de bateau / colis
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF9E6E4B),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9E6E4B).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.directions_boat_filled, size: 16, color: Colors.white),
      );
    } else {
      // Pastille grise avec point central bleu
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF1F5),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDCE2E8), width: 1.2),
        ),
        child: Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF5B92D1),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
  }

  /// Ligne de liaison verticale entre les étapes
  Widget _buildConnectingLine({bool isPassed = false, bool isDashed = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 13),
      width: 2,
      height: 22,
      child: isDashed
          ? CustomPaint(
              painter: _DashedLinePainter(
                color: const Color(0xFFBAC4CE),
              ),
            )
          : Container(
              color: isPassed ? const Color(0xFF1EB980) : const Color(0xFFBAC4CE),
            ),
    );
  }
}

/// Peintre de ligne pointillée verticale pour les étapes futures
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 3.5), paint);
      y += 6.5;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Peintre de la carte maritime stylisée : Chine 📍 ---> 🚢 Cargo ---> 📍 Bamako
class _MaritimeRoutePainter extends CustomPainter {
  final String departLabel;
  final String arriveeLabel;

  _MaritimeRoutePainter({
    required this.departLabel,
    required this.arriveeLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Coordonnées départ (Chine) et arrivée (Bamako)
    final pDepart = Offset(w * 0.14, h * 0.58);
    final pArrivee = Offset(w * 0.86, h * 0.58);

    // Tracé de la route maritime en courbe douce
    final path = Path()
      ..moveTo(pDepart.dx, pDepart.dy)
      ..cubicTo(
        w * 0.35,
        h * 0.32,
        w * 0.65,
        h * 0.32,
        pArrivee.dx,
        pArrivee.dy,
      );

    // Dessin de la ligne pointillée bleue
    final routePaint = Paint()
      ..color = const Color(0xFF4A8AC4)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    // Approximation de pointillés le long de la courbe
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extract = metric.extractPath(distance, distance + 4.5);
        canvas.drawPath(extract, routePaint);
        distance += 8.5;
      }
    }

    // 1. Point de départ (Chine) : Pin rouge
    final redPinPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawCircle(Offset(pDepart.dx, pDepart.dy - 10), 6.5, redPinPaint);
    canvas.drawCircle(Offset(pDepart.dx, pDepart.dy - 10), 2.5, Paint()..color = Colors.white);
    final textPainterDepart = TextPainter(
      text: TextSpan(
        text: departLabel,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF333333),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterDepart.layout();
    textPainterDepart.paint(canvas, Offset(pDepart.dx - (textPainterDepart.width / 2), pDepart.dy + 3));

    // 2. Point d'arrivée (Bamako) : Pin bleu
    final bluePinPaint = Paint()..color = const Color(0xFF1E88E5);
    canvas.drawCircle(Offset(pArrivee.dx, pArrivee.dy - 10), 6.5, bluePinPaint);
    canvas.drawCircle(Offset(pArrivee.dx, pArrivee.dy - 10), 2.5, Paint()..color = Colors.white);
    final textPainterArrivee = TextPainter(
      text: TextSpan(
        text: arriveeLabel,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF333333),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterArrivee.layout();
    textPainterArrivee.paint(canvas, Offset(pArrivee.dx - (textPainterArrivee.width / 2), pArrivee.dy + 3));

    // 3. Dessin du Cargo / Navire au centre du trajet
    final shipCenter = Offset(w * 0.50, h * 0.35);

    // Coque du bateau
    final hullPath = Path()
      ..moveTo(shipCenter.dx - 14, shipCenter.dy + 3)
      ..lineTo(shipCenter.dx + 14, shipCenter.dy + 3)
      ..lineTo(shipCenter.dx + 10, shipCenter.dy + 9)
      ..lineTo(shipCenter.dx - 11, shipCenter.dy + 9)
      ..close();
    canvas.drawPath(hullPath, Paint()..color = const Color(0xFF1E3A5F));

    // Conteneurs colorés sur le pont
    canvas.drawRect(
      Rect.fromLTWH(shipCenter.dx - 9, shipCenter.dy - 4, 6, 6),
      Paint()..color = const Color(0xFFEEA823),
    );
    canvas.drawRect(
      Rect.fromLTWH(shipCenter.dx - 2, shipCenter.dy - 4, 6, 6),
      Paint()..color = const Color(0xFF1EB980),
    );
    canvas.drawRect(
      Rect.fromLTWH(shipCenter.dx + 5, shipCenter.dy - 2, 5, 4),
      Paint()..color = const Color(0xFFE53935),
    );

    // Cabine blanche
    canvas.drawRect(
      Rect.fromLTWH(shipCenter.dx - 12, shipCenter.dy - 3, 3, 5),
      Paint()..color = Colors.white,
    );

    // Ondulations de vagues sous le bateau
    final wavePaint = Paint()
      ..color = const Color(0xFF7CB6E6).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(shipCenter.dx - 18, shipCenter.dy + 12),
      Offset(shipCenter.dx + 18, shipCenter.dy + 12),
      wavePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
