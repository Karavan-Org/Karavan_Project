import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_popups.dart';
import '../widgets/image_produit.dart';

/// Suivi du colis des groupes que le grossiste achemine lui-même : il valide chaque étape dans l'ordre,
/// chaque validation est notifiée immédiatement aux administrateurs dɔgɔ, qui mettent à jour le suivi
/// officiel vu par les commerçants (affiché ici aussi).
class SuiviColisGrossisteScreen extends StatefulWidget {
  const SuiviColisGrossisteScreen({super.key});

  /// Étapes de vérification, dans l'ordre de l'acheminement
  static const etapesColis = [
    "Marchandise commandée au fournisseur",
    "Colis expédiés",
    "En transit",
    "Arrivés à la frontière / en douane",
    "Dédouanés",
    "Arrivés au dépôt",
  ];

  @override
  State<SuiviColisGrossisteScreen> createState() => _SuiviColisGrossisteScreenState();
}

class _SuiviColisGrossisteScreenState extends State<SuiviColisGrossisteScreen> {
  List<GroupeResume> _groupes = [];
  final Map<int, List<Map<String, dynamic>>> _etapes = {};
  final Map<int, Map<String, dynamic>> _convois = {};
  bool _chargement = true;
  String? _erreur;
  int? _envoi;
  Timer? _timerActualisation;

  @override
  void initState() {
    super.initState();
    _charger();
    // Actualisation automatique en temps réel
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
      final service = GroupeApiService.instance;
      final groupes = (await service.groupesDuGrossiste())
          .where((g) => g.porteParGrossiste && !['BROUILLON', 'ANNULE', 'ECHOUE'].contains(g.statut))
          .toList();
      final convois = await service.convois();
      final etapes = <int, List<Map<String, dynamic>>>{};
      for (final g in groupes.where((g) => g.acheminementAuGrossiste || g.statut == 'TERMINE')) {
        etapes[g.id] = await service.etapes(g.id);
      }
      if (!mounted) return;
      setState(() {
        _groupes = groupes;
        _etapes
          ..clear()
          ..addAll(etapes);
        _convois
          ..clear()
          ..addEntries(convois.map((c) => MapEntry(((c['groupeId'] as num?) ?? 0).toInt(), c)));
      });
    } catch (_) {}
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final service = GroupeApiService.instance;
      final groupes = (await service.groupesDuGrossiste())
          .where((g) => g.porteParGrossiste && !['BROUILLON', 'ANNULE', 'ECHOUE'].contains(g.statut))
          .toList();
      final convois = await service.convois();
      final etapes = <int, List<Map<String, dynamic>>>{};
      for (final g in groupes.where((g) => g.acheminementAuGrossiste || g.statut == 'TERMINE')) {
        etapes[g.id] = await service.etapes(g.id);
      }
      if (!mounted) return;
      setState(() {
        _groupes = groupes;
        _etapes
          ..clear()
          ..addAll(etapes);
        _convois
          ..clear()
          ..addEntries(convois.map((c) => MapEntry(((c['groupeId'] as num?) ?? 0).toInt(), c)));
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

  /// Étapes déjà validées (par libellé) pour un groupe
  Set<String> _faites(int groupeId) => (_etapes[groupeId] ?? []).map((e) => e['etape']?.toString() ?? '').toSet();

  void _bloquerSuiviNonOuvert(GroupeResume g) {
    AppPopups.afficherActionImpossible(
      context: context,
      titre: "Suivi non encore ouvert par l'administrateur",
      message: "Vous ne pouvez pas valider d'étape de suivi tant que l'administrateur n'a pas accepté et officiellement ouvert le suivi de ce colis.",
      detail: "L'Admin Logistique (+22370000005) ou l'Admin Technique doit d'abord ouvrir le suivi du colis depuis la console Admin.",
    );
  }

  Future<void> _valider(GroupeResume g, String etape) async {
    if (!g.aAtteint100) {
      AppPopups.afficherActionImpossible(
        context: context,
        titre: "Objectif non atteint (100% requis)",
        message: "Vous ne pouvez pas lancer ou valider le suivi d'un colis tant que le groupe n'a pas atteint 100% de son objectif.",
        detail: "Progression actuelle : ${g.quantiteProgression} / ${g.quantiteCible} pièces (${g.pourcentageProgression}%).",
      );
      return;
    }
    final convoi = _convois[g.id];
    if (convoi == null) {
      _bloquerSuiviNonOuvert(g);
      return;
    }
    final commentaire = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Valider l'étape"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etape, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text("L'administrateur dɔgɔ est notifié immédiatement.",
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            TextField(
              controller: commentaire,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Précisions (transporteur, n° de suivi…)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            child: const Text("Valider et notifier"),
          ),
        ],
      ),
    );
    final texte = commentaire.text;
    commentaire.dispose();
    if (ok != true) return;
    setState(() => _envoi = g.id);
    try {
      await GroupeApiService.instance.signalerEtape(g.id, etape: etape, commentaire: texte);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("« $etape » validée : l'administrateur est notifié"), backgroundColor: AppTheme.success),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Suivi des colis", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _charger)],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _charger,
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _erreur != null
                ? _message(Icons.cloud_off_outlined, "Chargement impossible", _erreur!)
                : _groupes.isEmpty
                    ? _message(Icons.local_shipping_outlined, "Aucun colis à suivre",
                        "Le suivi apparaît ici pour les groupes que vous avez créés, une fois publiés.")
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        itemCount: _groupes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _carte(_groupes[i]),
                      ),
      ),
    );
  }

  Widget _carte(GroupeResume g) {
    final faites = _faites(g.id);
    final prochaine = SuiviColisGrossisteScreen.etapesColis.where((e) => !faites.contains(e)).firstOrNull;
    final convoi = _convois[g.id];
    final bool suiviOuvert = convoi != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE9E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFFF7F2EB),
                  child: imageProduit(g.photoUrl ?? '', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.titre.isNotEmpty ? g.titre : g.produitNom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    Text("Groupe n° ${g.id} • ${g.libelleStatut}",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: suiviOuvert ? AppTheme.tertiary.withValues(alpha: 0.35) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: suiviOuvert ? Colors.transparent : const Color(0xFFFFB74D)),
            ),
            child: Row(
              children: [
                Icon(
                  suiviOuvert ? Icons.local_shipping_outlined : Icons.hourglass_top_rounded,
                  size: 16,
                  color: suiviOuvert ? AppTheme.textDark : const Color(0xFFE65100),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    convoi != null
                        ? "Suivi officiel dɔgɔ : ${convoi['statut']}"
                        : "Suivi officiel dɔgɔ : pas encore ouvert par l'administrateur",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: suiviOuvert ? AppTheme.textDark : const Color(0xFFB71C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!g.aAtteint100)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFFE65100), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Suivi verrouillé (${g.pourcentageProgression}%) : Ce groupe doit atteindre 100% de ses réservations (${g.quantiteProgression}/${g.quantiteCible}) avant que les étapes d'acheminement ne puissent être initiées.",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB71C1C)),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (!suiviOuvert)
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock_outlined, color: Color(0xFFE65100), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "L'objectif de 100% est atteint. Les étapes d'acheminement ne peuvent pas être validées tant que l'administrateur n'a pas accepté et ouvert le suivi du colis.",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5D4037)),
                      ),
                    ),
                  ],
                ),
              ),
            for (final e in SuiviColisGrossisteScreen.etapesColis)
              _ligneEtape(g, e, faites, e == prochaine, suiviOuvert),
            if (prochaine == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text("Toutes les étapes sont validées.",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _ligneEtape(GroupeResume g, String etape, Set<String> faites, bool estProchaine, bool suiviOuvert) {
    final faite = faites.contains(etape);
    final infos = (_etapes[g.id] ?? []).where((x) => x['etape'] == etape).firstOrNull;
    final date = DateTime.tryParse(infos?['date']?.toString() ?? '')?.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            faite ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: faite ? AppTheme.success : const Color(0xFFC7B8AA),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etape,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: faite || estProchaine ? FontWeight.w700 : FontWeight.w500,
                      color: faite || estProchaine ? AppTheme.textDark : AppTheme.textMuted,
                    )),
                if (date != null)
                  Text(
                    "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} "
                    "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}"
                    "${infos?['commentaire'] != null ? ' • ${infos!['commentaire']}' : ''}",
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
          if (estProchaine)
            if (!suiviOuvert)
              OutlinedButton.icon(
                onPressed: () => _bloquerSuiviNonOuvert(g),
                icon: const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFFE65100)),
                label: const Text(
                  "En attente admin",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFE65100)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFB74D)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              )
            else
              ElevatedButton(
                onPressed: _envoi == null ? () => _valider(g, etape) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _envoi == g.id
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Valider", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
        ],
      ),
    );
  }

  Widget _message(IconData icone, String titre, String texte) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(icone, size: 48, color: AppTheme.primary),
        const SizedBox(height: 14),
        Text(titre, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        Text(texte, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ],
    );
  }
}
