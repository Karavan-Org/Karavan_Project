import '../widgets/tab_navigation_scope.dart';
import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/carte_groupe.dart';
import '../services/visibilite_ecran.dart';

/// Lots du Grossiste : groupes dont l'objectif est atteint, avec les commandes à préparer
/// (GET /api/groupes/{id}/commandes ; l'identité des acheteurs n'est pas transmise au grossiste, RG-71).
class GrossisteCommandesScreen extends StatefulWidget {
  const GrossisteCommandesScreen({super.key});

  @override
  State<GrossisteCommandesScreen> createState() => _GrossisteCommandesScreenState();
}

class _GrossisteCommandesScreenState extends State<GrossisteCommandesScreen> with SingleTickerProviderStateMixin, ActualisationAutomatique<GrossisteCommandesScreen> {
  static const _aPreparer = ['OBJECTIF_ATTEINT'];
  static const _expedies = ['EN_EXPEDITION', 'LIVRE', 'TERMINE'];

  late final TabController _onglets = TabController(length: 2, vsync: this);
  List<GroupeResume> _groupes = [];
  final Map<int, List<Map<String, dynamic>>> _commandes = {};
  bool _chargement = true;
  String? _erreur;

  /// Données vivantes : relues en arrière-plan tant que l'écran est affiché
  @override
  Future<void> actualiserEnSilence() async {
    await _charger(silencieux: true);
  }

  @override
  void initState() {
    super.initState();
    demarrerActualisation();
    _charger();
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    if (!silencieux) {
      setState(() {
        _chargement = true;
        _erreur = null;
      });
    }
    try {
      final groupes = (await GroupeApiService.instance.groupesDuGrossiste())
          .where((g) => _aPreparer.contains(g.statut) || _expedies.contains(g.statut))
          .toList();
      final commandes = await Future.wait(groupes.map((g) => GroupeApiService.instance.commandesDuGroupe(g.id)));
      if (!mounted) return;
      setState(() {
        _groupes = groupes;
        _commandes
          ..clear()
          ..addAll({for (var i = 0; i < groupes.length; i++) groupes[i].id: commandes[i]});
        _chargement = false;
      });
    } catch (e) {
      if (silencieux) return;
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : '$e';
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aPreparer = _groupes.where((g) => _aPreparer.contains(g.statut)).toList();
    final expedies = _groupes.where((g) => _expedies.contains(g.statut)).toList();
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
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
        backgroundColor: AppTheme.couleurCarte(context),
        elevation: 0,
        centerTitle: false,
        title: Text(
          "Lots & commandes",
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
        bottom: TabBar(
          controller: _onglets,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.couleurTexteAttenue(context),
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(text: "À préparer (${aPreparer.length})"),
            Tab(text: "Expédiés (${expedies.length})"),
          ],
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: AppTheme.olive))
          : TabBarView(
              controller: _onglets,
              children: [_liste(aPreparer), _liste(expedies)],
            ),
    );
  }

  Widget _liste(List<GroupeResume> groupes) {
    return RefreshIndicator(
      color: AppTheme.olive,
      onRefresh: _charger,
      child: groupes.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 40),
                Icon(Icons.inbox_outlined, size: 48, color: AppTheme.couleurTexteAttenue(context).withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  _erreur ?? "Aucun lot ici. Un lot apparaît quand un groupe monté sur vos produits atteint son objectif.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: groupes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final g = groupes[i];
                final commandes = _commandes[g.id] ?? const [];
                return CarteGroupe(
                  groupe: g,
                  partenaire: g.courtierNom.isEmpty ? '' : "Courtier : ${g.courtierNom}",
                  action: _detailCommandes(commandes),
                );
              },
            ),
    );
  }

  Widget _detailCommandes(List<Map<String, dynamic>> commandes) {
    final pieces = commandes.fold<int>(0, (t, c) => t + ((c['quantite'] as num?) ?? 0).toInt());
    // Regroupe les pièces à préparer par variante (SKU / taille / couleur)
    final parVariante = <String, int>{};
    for (final c in commandes) {
      final cle = [c['sku'], c['taille'], c['couleur']].where((x) => x != null && '$x'.isNotEmpty).join(' • ');
      parVariante[cle] = (parVariante[cle] ?? 0) + ((c['quantite'] as num?) ?? 0).toInt();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.couleurSurfaceDouce(context), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${commandes.length} commande${commandes.length > 1 ? 's' : ''} • $pieces pièce${pieces > 1 ? 's' : ''}",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.couleurTexte(context)),
          ),
          for (final e in parVariante.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("${e.key} : ${e.value} pcs", style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context))),
            ),
        ],
      ),
    );
  }
}
