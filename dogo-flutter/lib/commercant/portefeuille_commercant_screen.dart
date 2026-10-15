import 'package:flutter/material.dart';
import '../models/participation_model.dart';
import '../models/remboursement_model.dart';
import '../services/auth_service.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/zone_portefeuille_neumorphic.dart';
import '../widgets/app_popups.dart';
import '../services/portefeuille_api_service.dart';

/// Écran Portefeuille Achats du Commerçant (Frame Figma "Portefeuille Achats")
/// Affiche le solde disponible (remboursements validés, recharges) et les fonds en séquestre.
class PortefeuilleCommercantScreen extends StatefulWidget {
  const PortefeuilleCommercantScreen({super.key});

  @override
  State<PortefeuilleCommercantScreen> createState() => _PortefeuilleCommercantScreenState();
}

class _PortefeuilleCommercantScreenState extends State<PortefeuilleCommercantScreen> {
  int _soldeDisponible = 0;
  int _soldeSequestre = 0;
  bool _chargement = true;

  final List<Map<String, dynamic>> _mouvements = [];

  @override
  void initState() {
    super.initState();
    _chargerDonneesPortefeuille();
  }

  Future<void> _chargerDonneesPortefeuille() async {
    setState(() => _chargement = true);
    try {
      final futures = await Future.wait([
        PortefeuilleApiService.instance.voirPortefeuille(),
        PortefeuilleApiService.instance.mesMouvements(),
        GroupeApiService.instance.mesRemboursements(),
        GroupeApiService.instance.mesParticipations(),
      ]);

      final portefeuilleInfo = futures[0] as PortefeuilleInfo?;
      final mouvementsPortefeuille = futures[1] as List<MouvementPortefeuille>;
      final remboursements = futures[2] as List<RemboursementModel>;
      final participations = futures[3] as List<ParticipationModel>;

      int totalRembourse = 0;
      int totalSequestre = 0;
      final List<Map<String, dynamic>> mvts = [];

      // 1. Mouvements officiels du portefeuille backend (Recharges, Paiements, Remboursements)
      for (final m in mouvementsPortefeuille) {
        final montantEntier = m.montant.toInt();
        final dateFormatee = m.date != null
            ? "${m.date!.day.toString().padLeft(2, '0')}/${m.date!.month.toString().padLeft(2, '0')} à ${m.date!.hour.toString().padLeft(2, '0')}h${m.date!.minute.toString().padLeft(2, '0')}"
            : "Récemment";

        if (m.type == 'RECHARGE_PORTEFEUILLE') {
          mvts.add({
            "titre": "Recharge Portefeuille",
            "description": "Mobile Money • Solde crédité",
            "montant": "+${montantEntier.toString()} F",
            "isCredit": true,
            "isPending": false,
            "date": dateFormatee,
            "statut": "Effectué",
            "timestamp": m.date?.millisecondsSinceEpoch ?? 0,
          });
        } else if (m.type == 'DEBIT_COMMERCANT') {
          mvts.add({
            "titre": "Paiement commande groupée",
            "description": "Règlement par Portefeuille Achats",
            "montant": "-${montantEntier.toString()} F",
            "isCredit": false,
            "isPending": false,
            "date": dateFormatee,
            "statut": "Payé",
            "timestamp": m.date?.millisecondsSinceEpoch ?? 0,
          });
        } else if (m.type == 'REMBOURSEMENT') {
          mvts.add({
            "titre": "Remboursement validé",
            "description": "Fonds restitués sur votre portefeuille",
            "montant": "+${montantEntier.toString()} F",
            "isCredit": true,
            "isPending": false,
            "date": dateFormatee,
            "statut": "Crédité",
            "timestamp": m.date?.millisecondsSinceEpoch ?? 0,
          });
        }
      }

      // 2. Remboursements exécutés & en examen
      for (final r in remboursements) {
        final montantEntier = r.montant.toInt();
        final nom = (r.produitNom != null && r.produitNom!.isNotEmpty) ? r.produitNom! : "Commande groupée";
        final dateFormatee = r.dateDemande != null
            ? "${r.dateDemande!.day.toString().padLeft(2, '0')}/${r.dateDemande!.month.toString().padLeft(2, '0')} à ${r.dateDemande!.hour.toString().padLeft(2, '0')}h${r.dateDemande!.minute.toString().padLeft(2, '0')}"
            : "Récemment";

        if (r.execute) {
          totalRembourse += montantEntier;
          final existeDeja = mvts.any((x) => x["montant"] == "+${montantEntier.toString()} F" && x["isCredit"] == true);
          if (!existeDeja) {
            mvts.add({
              "titre": "Remboursement validé",
              "description": "« $nom » • Validé par l'administration",
              "montant": "+${montantEntier.toString()} F",
              "isCredit": true,
              "isPending": false,
              "date": dateFormatee,
              "statut": "Crédité",
              "timestamp": r.dateDemande?.millisecondsSinceEpoch ?? 0,
            });
          }
        } else if (r.enTraitement) {
          mvts.add({
            "titre": "Remboursement en examen",
            "description": "« $nom » • Arbitrage admin en cours",
            "montant": "${montantEntier.toString()} F",
            "isCredit": false,
            "isPending": true,
            "date": dateFormatee,
            "statut": "En examen",
            "timestamp": r.dateDemande?.millisecondsSinceEpoch ?? 0,
          });
        }
      }

      // 3. Participations actives en séquestre
      for (final p in participations) {
        if (p.statut == 'CONFIRMEE') {
          totalSequestre += p.montant.toInt();
          final dateFormatee = p.dateCreation != null
              ? "${p.dateCreation!.day.toString().padLeft(2, '0')}/${p.dateCreation!.month.toString().padLeft(2, '0')} à ${p.dateCreation!.hour.toString().padLeft(2, '0')}h${p.dateCreation!.minute.toString().padLeft(2, '0')}"
              : "Récemment";
          mvts.add({
            "titre": "Paiement sous séquestre",
            "description": "« ${p.produit} » (${p.quantite} pcs) • Fonds protégés",
            "montant": "-${p.montant.toInt()} F",
            "isCredit": false,
            "isPending": false,
            "date": dateFormatee,
            "statut": "Séquestre",
            "timestamp": p.dateCreation?.millisecondsSinceEpoch ?? 0,
          });
        }
      }

      // Tri chronologique descendant
      mvts.sort((a, b) => (b["timestamp"] as int).compareTo(a["timestamp"] as int));

      int soldeDispoFinal = 0;
      if (portefeuilleInfo != null) {
        soldeDispoFinal = portefeuilleInfo.soldeDisponible.toInt();
      }
      if (totalRembourse > soldeDispoFinal) {
        soldeDispoFinal = totalRembourse;
      }

      if (mounted) {
        setState(() {
          _soldeDisponible = soldeDispoFinal;
          _soldeSequestre = totalSequestre;
          _mouvements.clear();
          _mouvements.addAll(mvts);
        });
      }
    } catch (e) {
      debugPrint("PortefeuilleCommercantScreen - Erreur chargement : $e");
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _showRechargeModal({String operateurInitial = "Orange Money"}) {
    final montantController = TextEditingController(text: "50000");
    String selectedOperateur = operateurInitial;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5DDD5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Recharger mon Portefeuille",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                "Créditez votre compte pour valider vos achats groupés instantanément.",
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),
              const Text("Choisir l'opérateur :", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildOperateurChip("Orange Money", selectedOperateur, (op) => setModalState(() => selectedOperateur = op)),
                  const SizedBox(width: 8),
                  _buildOperateurChip("Moov Africa", selectedOperateur, (op) => setModalState(() => selectedOperateur = op)),
                  const SizedBox(width: 8),
                  _buildOperateurChip("Wave", selectedOperateur, (op) => setModalState(() => selectedOperateur = op)),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Montant (FCFA) :", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: montantController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: "FCFA",
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final montant = int.tryParse(montantController.text) ?? 0;
                    if (montant > 0) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text("Recharge en cours..."),
                            ],
                          ),
                          duration: Duration(seconds: 1),
                        ),
                      );

                      try {
                        await PortefeuilleApiService.instance.recharger(
                          montant: montant.toDouble(),
                          operateur: selectedOperateur,
                        );

                        if (!mounted) return;
                        await _chargerDonneesPortefeuille();
                        if (!mounted) return;
                        AppPopups.afficher(
                          context: context,
                          titre: "Recharge validée !",
                          message: "Votre portefeuille a été crédité de ${montantController.text} FCFA avec succès.",
                          detailSupplementaire: "Ce montant est immédiatement disponible pour régler vos achats groupés.",
                          icone: Icons.check_circle_outline_rounded,
                          couleurIcone: const Color(0xFF1B5E20),
                          couleurFondIcone: const Color(0xFFE8F5E9),
                          boutonTexte: "Fermer et continuer",
                        );
                      } catch (e) {
                        if (mounted) {
                          await AppPopups.traiterErreurOuConflit(context, e);
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7D4F27),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Confirmer la Recharge", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperateurChip(String nom, String selected, ValueChanged<String> onSelect) {
    final isSelected = nom == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(nom),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7D4F27) : const Color(0xFFF7F2EC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF7D4F27) : const Color(0xFFE5DDD5)),
          ),
          child: Text(
            nom,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomCommercant = AuthService.instance.profilActuel?.nom ?? "Espace Commerçant DoGo";

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C241E)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Portefeuille Achats",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF2C241E)),
            ),
            Text(
              nomCommercant,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF9E6738), size: 22),
            tooltip: "Actualiser",
            onPressed: _chargerDonneesPortefeuille,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _chargerDonneesPortefeuille,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ZONE PORTEFEUILLE NEUMORPHIQUE SOFT 3D (Style Maquette) ---
              ZonePortefeuilleNeumorphic(
                titre: "Portefeuille Achats",
                sousTitre: "Disponible pour vos commandes groupées",
                montantSolde: "$_soldeDisponible FCFA",
                infoSequestre: "Séquestre garanti : $_soldeSequestre F • Libéré à la réception de vos colis",
                iconeInfo: Icons.lock_outline_rounded,
                texteBoutonAction: "Recharger mon Portefeuille",
                onTapAction: () => _showRechargeModal(),
                couleurBouton: const [
                  Color(0xFFB87333),
                  Color(0xFF915123),
                  Color(0xFF753812),
                ],
                couleurEmbleme: const [
                  Color(0xFFFFFFFF),
                  Color(0xFFE5A100),
                  Color(0xFF9E5C23),
                ],
                titreSquirclesRapides: "RECHARGER VIA MOBILE MONEY",
                squirclesRapides: [
                  ZonePortefeuilleNeumorphic.buildSquircleRapide(
                    label: "Orange",
                    onTap: () => _showRechargeModal(operateurInitial: "Orange Money"),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF7900),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "OM",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  ZonePortefeuilleNeumorphic.buildSquircleRapide(
                    label: "Moov",
                    onTap: () => _showRechargeModal(operateurInitial: "Moov Africa"),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF005DAA),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "MM",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  ZonePortefeuilleNeumorphic.buildSquircleRapide(
                    label: "Wave",
                    onTap: () => _showRechargeModal(operateurInitial: "Wave"),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1DC4F2),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.waves_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // --- MOUVEMENTS & COMMANDES ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Mouvements & commandes",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2C241E)),
                  ),
                  TextButton.icon(
                    onPressed: _chargerDonneesPortefeuille,
                    icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF9E6738)),
                    label: const Text(
                      "Actualiser",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9E6738)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Liste des mouvements ou état vide
              if (_chargement && _mouvements.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                )
              else if (_mouvements.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEFE8DD), width: 1.2),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        "Aucun mouvement récent",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Vos remboursements validés et paiements sécurisés s'afficheront ici.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _mouvements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final m = _mouvements[index];
                    final bool isCredit = m["isCredit"] as bool;
                    final bool isPending = m["isPending"] == true;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0646321E), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isCredit
                                  ? const Color(0xFFE8F5E9)
                                  : (isPending ? const Color(0xFFFFF8E1) : const Color(0xFFFBE9E7)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCredit
                                  ? Icons.arrow_downward_rounded
                                  : (isPending ? Icons.hourglass_top_rounded : Icons.lock_outline_rounded),
                              color: isCredit
                                  ? AppTheme.success
                                  : (isPending ? const Color(0xFFF57F17) : const Color(0xFFC62828)),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m["titre"] as String,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2C241E)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  m["description"] as String,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (m["date"] != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    m["date"] as String,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFFA09085)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                m["montant"] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isCredit
                                      ? AppTheme.success
                                      : (isPending ? const Color(0xFFF57F17) : const Color(0xFFC62828)),
                                ),
                              ),
                              if (m["statut"] != null) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? const Color(0xFFE8F5E9)
                                        : (isPending ? const Color(0xFFFFF8E1) : const Color(0xFFFFF3E0)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    m["statut"] as String,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isCredit
                                          ? const Color(0xFF2E7D32)
                                          : (isPending ? const Color(0xFFF57F17) : const Color(0xFFE65100)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 20),

              // Note de garantie DoGo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EDE4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: Color(0xFF9E6738)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Votre argent reste protégé sous séquestre jusqu'à la remise et vérification de votre commande.",
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF5A493B), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
