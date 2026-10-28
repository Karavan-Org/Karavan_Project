import '../widgets/tab_navigation_scope.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_popups.dart';
import '../widgets/carte_groupe.dart';
import '../widgets/partage_groupe.dart';
import 'suivi_colis_grossiste_screen.dart';
import '../services/visibilite_ecran.dart';

/// Groupes d'achat montés sur les produits du Grossiste (GET /api/groupes/du-grossiste) : ceux qu'il a créés
/// lui-même (il les partage et signale les étapes de leur acheminement à Karavan), et ceux des courtiers,
/// dont il confirme la disponibilité du stock (RG-18).
class MesGroupesGrossisteScreen extends StatefulWidget {
  final String titre;
  final String filtreInitial;

  const MesGroupesGrossisteScreen({super.key, this.titre = "Mes groupes d'achat", this.filtreInitial = "Tous"});

  @override
  State<MesGroupesGrossisteScreen> createState() => _MesGroupesGrossisteScreenState();
}

class _MesGroupesGrossisteScreenState extends State<MesGroupesGrossisteScreen> {
  static const _filtres = ["Tous", "À confirmer", "Ouverts", "Clôturés"];

  late String _filtre = widget.filtreInitial;
  List<GroupeResume> _groupes = [];
  bool _chargement = true;
  String? _erreur;
  int? _enConfirmation;
  Timer? _timerActualisation;

  @override
  void initState() {
    super.initState();
    _charger();
    // Actualisation dynamique en direct de la jauge et des réservations
    _timerActualisation = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && ecranVisible(context)) _actualiserSilencieux();
    });
  }

  @override
  void dispose() {
    _timerActualisation?.cancel();
    super.dispose();
  }

  Future<void> _actualiserSilencieux() async {
    if (!mounted || _chargement) return;
    try {
      final groupes = await GroupeApiService.instance.groupesDuGrossiste();
      if (!mounted) return;
      setState(() {
        _groupes = groupes;
      });
    } catch (_) {}
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final groupes = await GroupeApiService.instance.groupesDuGrossiste();
      if (!mounted) return;
      setState(() {
        _groupes = groupes;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : '$e';
        _chargement = false;
      });
    }
  }

  bool _aConfirmer(GroupeResume g) => g.statut == 'EN_VALIDATION' && !g.disponibiliteValidee;

  List<GroupeResume> get _filtres_ => switch (_filtre) {
        "À confirmer" => _groupes.where(_aConfirmer).toList(),
        "Ouverts" => _groupes.where((g) => g.statut == 'OUVERT').toList(),
        "Clôturés" => _groupes
            .where((g) => !['BROUILLON', 'EN_VALIDATION', 'OUVERT'].contains(g.statut))
            .toList(),
        _ => _groupes,
      };

  Future<void> _confirmer(GroupeResume g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirmer le stock"),
        content: Text(
          "Vous confirmez disposer de ${g.quantiteCible} pièces de « ${g.produitNom} » pour le groupe n° ${g.id} "
          "(courtier : ${g.courtierNom}).",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text("Je confirme"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _enConfirmation = g.id);
    try {
      await GroupeApiService.instance.validerDisponibilite(g.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Stock confirmé : le groupe attend maintenant la publication par Karavan"),
          backgroundColor: AppTheme.success,
        ),
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : 'Confirmation impossible : $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _enConfirmation = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupes = _filtres_;
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),
        title: Text(
          widget.titre,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.couleurTexte(context),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.couleurTexte(context)),
            tooltip: "Actualiser",
            onPressed: _charger,
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                for (final f in _filtres) ...[_puce(f), const SizedBox(width: 8)],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.olive,
              onRefresh: _charger,
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.olive))
                  : _erreur != null
                      ? _etat(Icons.cloud_off_outlined, "Chargement impossible", _erreur!)
                      : groupes.isEmpty
                          ? _etat(
                              Icons.groups_outlined,
                              "Aucun groupe",
                              "Sélectionnez un produit de votre catalogue et appuyez sur + pour lancer un groupe. "
                                  "Les groupes montés par des courtiers sur vos produits apparaissent aussi ici.",
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                              itemCount: groupes.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, i) {
                                final g = groupes[i];
                                return CarteGroupe(
                                  groupe: g,
                                  partenaire: g.porteParGrossiste
                                      ? "Votre groupe • acheminement par vos soins"
                                      : (g.courtierNom.isEmpty ? '' : "Courtier : ${g.courtierNom}"),
                                  action: _aConfirmer(g)
                                      ? ElevatedButton.icon(
                                          onPressed: _enConfirmation == null ? () => _confirmer(g) : null,
                                          icon: _enConfirmation == g.id
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : const Icon(Icons.fact_check_rounded, size: 18),
                                          label: const Text("Confirmer mon stock"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(double.infinity, 42),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                          ),
                                        )
                                      : _actions(g),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  void _bloquerSuiviIncomplet(GroupeResume g) {
    AppPopups.afficherActionImpossible(
      context: context,
      titre: "Objectif non atteint (100% requis)",
      message: "Le suivi du colis ne peut pas être lancé tant que le groupe n'a pas atteint 100% de son objectif.",
      detail: "Progression actuelle : ${g.quantiteProgression} / ${g.quantiteCible} pièces réservées (${g.pourcentageProgression}%).\n\n"
          "Dès que toutes les pièces auront été réservées par les commerçants, le suivi logistique et les étapes d'acheminement seront automatiquement débloqués.",
    );
  }

  /// Partage du lien et accès au suivi du colis (strictement conditionné à 100% de réservations)
  Widget? _actions(GroupeResume g) {
    final partageable = g.statut == 'OUVERT' || (g.porteParGrossiste && g.statut == 'EN_VALIDATION');
    final suiviAutorise = g.acheminementAuGrossiste;
    final doitAfficherBoutonSuivi = g.porteParGrossiste && (g.aAtteint100 || g.statut == 'OUVERT');

    if (!partageable && !doitAfficherBoutonSuivi) return null;

    return Row(
      children: [
        if (partageable) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => afficherPartageGroupe(context, g),
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text("Partager"),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
          if (doitAfficherBoutonSuivi) const SizedBox(width: 8),
        ],
        if (doitAfficherBoutonSuivi)
          Expanded(
            child: suiviAutorise
                ? ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SuiviColisGrossisteScreen()),
                    ).then((_) => _actualiserSilencieux()),
                    icon: const Icon(Icons.local_shipping_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("Suivi du colis"),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _bloquerSuiviIncomplet(g),
                    icon: Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.couleurTexteAttenue(context)),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Suivi (${g.pourcentageProgression}%)",
                        style: TextStyle(color: AppTheme.couleurTexteAttenue(context), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.couleurBordureForte(context)),
                      backgroundColor: AppTheme.couleurSurfaceDouce(context),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _etat(IconData icone, String titre, String texte) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(icone, size: 48, color: AppTheme.primary),
        const SizedBox(height: 14),
        Text(
          titre,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.couleurTexte(context)),
        ),
        const SizedBox(height: 6),
        Text(texte, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context))),
      ],
    );
  }

  Widget _puce(String label) {
    final actif = _filtre == label;
    final nombre = label == "À confirmer" ? _groupes.where(_aConfirmer).length : 0;
    return GestureDetector(
      onTap: () => setState(() => _filtre = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: actif ? AppTheme.bissap : AppTheme.couleurCarte(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: actif ? AppTheme.bissap : AppTheme.couleurBordure(context)),
        ),
        child: Text(
          nombre > 0 ? "$label ($nombre)" : label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
            color: actif ? Colors.white : AppTheme.couleurTexte(context),
          ),
        ),
      ),
    );
  }
}
