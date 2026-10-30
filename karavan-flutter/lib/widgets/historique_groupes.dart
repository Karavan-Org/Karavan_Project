import 'package:flutter/material.dart';
import '../models/statut_groupe.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'image_produit.dart';

/// Historique des groupes clos d'un Courtier ou d'un Grossiste, lu sur le serveur : groupes livrés,
/// terminés, annulés ou échoués, avec les quantités confirmées et le montant correspondant.
class HistoriqueGroupesScreen extends StatefulWidget {
  final RoleActeur role;

  const HistoriqueGroupesScreen({super.key, required this.role});

  @override
  State<HistoriqueGroupesScreen> createState() => _HistoriqueGroupesScreenState();
}

class _HistoriqueGroupesScreenState extends State<HistoriqueGroupesScreen> {
  /// Statuts qui sortent un groupe du suivi actif (StatutGroupe du backend)
  static const _clos = {'LIVRE', 'TERMINE', 'ANNULE', 'ECHOUE'};

  List<GroupeResume>? _groupes;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final api = GroupeApiService.instance;
      final tous = widget.role == RoleActeur.courtier ? await api.mesGroupesCourtier() : await api.groupesDuGrossiste();
      final clos = tous.where((g) => _clos.contains(g.statut)).toList()
        ..sort((a, b) => (b.dateLimite ?? DateTime(0)).compareTo(a.dateLimite ?? DateTime(0)));
      if (!mounted) return;
      setState(() {
        _groupes = clos;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e is ApiException ? e.messageComplet : "Impossible de charger l'historique.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupes = _groupes;
    final aboutis = groupes?.where((g) => g.statut == 'LIVRE' || g.statut == 'TERMINE').toList() ?? const [];
    final volume = aboutis.fold<num>(0, (s, g) => s + g.quantiteConfirmee * g.prixUnitaire);

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(title: Text(widget.role == RoleActeur.courtier ? "Historique des groupes" : "Historique des ventes")),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_erreur != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_rounded, color: AppTheme.danger),
                  title: Text(_erreur!),
                  trailing: TextButton(onPressed: _charger, child: const Text("Réessayer")),
                ),
              )
            else if (groupes == null)
              const Padding(padding: EdgeInsets.only(top: 160), child: Center(child: CircularProgressIndicator()))
            else if (groupes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Column(children: [
                  Icon(Icons.history_rounded, size: 48, color: AppTheme.couleurTexteAttenue(context)),
                  const SizedBox(height: 12),
                  Text("Aucun groupe clos pour l'instant", style: AppTheme.styleTitreMoyen(context)),
                  const SizedBox(height: 6),
                  Text(
                    "Vos groupes livrés, terminés ou annulés apparaîtront ici.",
                    textAlign: TextAlign.center,
                    style: AppTheme.styleCorpsAttenue(context),
                  ),
                ]),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: _chiffre(context, "${aboutis.length}", "groupe${aboutis.length > 1 ? 's' : ''} abouti${aboutis.length > 1 ? 's' : ''}")),
                    Expanded(child: _chiffre(context, formaterFcfa(volume), "volume livré")),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              for (final g in groupes)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(width: 46, height: 46, child: imageProduit(g.photoUrl ?? '', fit: BoxFit.cover)),
                    ),
                    title: Text(g.titre.isNotEmpty ? g.titre : g.produitNom, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      "${g.quantiteConfirmee} / ${g.quantiteCible} pièces • "
                      "${formaterFcfa(g.quantiteConfirmee * g.prixUnitaire)}"
                      "${widget.role == RoleActeur.courtier ? '' : (g.courtierNom.isNotEmpty ? ' • ${g.courtierNom}' : '')}",
                    ),
                    trailing: StatutGroupe.badge(g.statut),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chiffre(BuildContext context, String valeur, String libelle) => Column(children: [
        Text(valeur, style: AppTheme.styleTitreMoyen(context)),
        const SizedBox(height: 2),
        Text(libelle, style: AppTheme.styleCorpsAttenue(context)),
      ]);
}
