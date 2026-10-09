import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/carte_groupe.dart';
import '../widgets/partage_groupe.dart';
import 'suivi_colis_grossiste_screen.dart';

/// Groupes d'achat montés sur les produits du Grossiste (GET /api/groupes/du-grossiste) : ceux qu'il a créés
/// lui-même (il les partage et signale les étapes de leur acheminement à dɔgɔ), et ceux des courtiers,
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
          content: Text("Stock confirmé : le groupe attend maintenant la publication par dɔgɔ"),
          backgroundColor: AppTheme.success,
        ),
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : 'Confirmation impossible : $e'),
          backgroundColor: const Color(0xFFC0392B),
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
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C241E)),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          widget.titre,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
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
              color: AppTheme.primary,
              onRefresh: _charger,
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
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

  /// Partage du lien (groupe en attente de publication ou ouvert) et signalement des étapes d'acheminement
  Widget? _actions(GroupeResume g) {
    final partageable = g.statut == 'OUVERT' || (g.porteParGrossiste && g.statut == 'EN_VALIDATION');
    if (!partageable && !g.acheminementAuGrossiste) return null;
    return Row(
      children: [
        if (partageable)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => afficherPartageGroupe(context, g),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text("Partager le lien"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
        if (g.acheminementAuGrossiste)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuiviColisGrossisteScreen()),
              ).then((_) => _charger()),
              icon: const Icon(Icons.local_shipping_rounded, size: 18),
              label: const Text("Suivi du colis"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2C241E)),
        ),
        const SizedBox(height: 6),
        Text(texte, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
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
          color: actif ? const Color(0xFF9E6738) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: actif ? const Color(0xFF9E6738) : const Color(0xFFE5DDD5)),
        ),
        child: Text(
          nombre > 0 ? "$label ($nombre)" : label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
            color: actif ? Colors.white : const Color(0xFF5A493B),
          ),
        ),
      ),
    );
  }
}
