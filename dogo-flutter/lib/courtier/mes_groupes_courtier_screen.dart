import '../widgets/tab_navigation_scope.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/carte_groupe.dart';
import 'creer_groupe_courtier_screen.dart';

/// Groupes d'achat créés par le Courtier (GET /api/groupes/mes-groupes). Un brouillon peut être envoyé au
/// grossiste pour confirmation du stock (BROUILLON → EN_VALIDATION, RG-18).
class MesGroupesCourtierScreen extends StatefulWidget {
  const MesGroupesCourtierScreen({super.key});

  @override
  State<MesGroupesCourtierScreen> createState() => _MesGroupesCourtierScreenState();
}

class _MesGroupesCourtierScreenState extends State<MesGroupesCourtierScreen> {
  List<GroupeResume> _groupes = [];
  bool _chargement = true;
  String? _erreur;
  int? _envoi;
  Timer? _timerActualisation;

  @override
  void initState() {
    super.initState();
    _charger();
    _timerActualisation = Timer.periodic(const Duration(seconds: 4), (_) {
      _actualiserSilencieux();
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
      final groupes = await GroupeApiService.instance.mesGroupesCourtier();
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
      final groupes = await GroupeApiService.instance.mesGroupesCourtier();
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

  Future<void> _creer() async {
    final cree = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreerGroupeCourtierScreen()),
    );
    if (cree == true) _charger();
  }

  Future<void> _soumettre(GroupeResume g) async {
    setState(() => _envoi = g.id);
    try {
      await GroupeApiService.instance.soumettre(g.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Groupe envoyé au grossiste"), backgroundColor: AppTheme.success),
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : 'Envoi impossible : $e'),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    } finally {
      if (mounted) setState(() => _envoi = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          "Mes groupes d'achat",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF9E6738)),
            tooltip: "Nouveau groupe",
            onPressed: _creer,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _charger,
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _groupes.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.groups_outlined, size: 48, color: AppTheme.primary),
                      const SizedBox(height: 14),
                      Text(
                        _erreur ?? "Aucun groupe pour l'instant",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.couleurTexte(context)),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _creer,
                          icon: const Icon(Icons.group_add_rounded),
                          label: const Text("Créer un groupe d'achat"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    itemCount: _groupes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final g = _groupes[i];
                      return CarteGroupe(
                        groupe: g,
                        partenaire: g.grossisteNom.isEmpty ? '' : "Grossiste : ${g.grossisteNom}",
                        action: g.statut == 'BROUILLON'
                            ? OutlinedButton.icon(
                                onPressed: _envoi == null ? () => _soumettre(g) : null,
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: const Text("Envoyer au grossiste"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  minimumSize: const Size(double.infinity, 42),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
      ),
    );
  }
}
