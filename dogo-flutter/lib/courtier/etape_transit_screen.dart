import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/courtier_api_service.dart';
import '../services/api/api_exception.dart';

/// Suivi des convois du Courtier (GET /api/convois) et validation des jalons :
/// ACHETE → CHEZ_TRANSITAIRE → EN_TRANSIT ⇄ BLOQUE_DOUANE → ARRIVE, plus des jalons libres (statut + lieu).
class EtapeTransitScreen extends StatefulWidget {
  const EtapeTransitScreen({super.key});

  static String libelleStatut(String statut) => switch (statut) {
        "ACHETE" => "Marchandise achetée",
        "CHEZ_TRANSITAIRE" => "Chez le transitaire",
        "EN_TRANSIT" => "En transit",
        "BLOQUE_DOUANE" => "Bloqué en douane",
        "ARRIVE" => "Arrivé",
        "CREATION_CONVOI" => "Convoi créé",
        _ => statut,
      };

  @override
  State<EtapeTransitScreen> createState() => _EtapeTransitScreenState();
}

/// Action possible depuis un statut : endpoint `/api/convois/{id}/<action>`, libellé, et saisie du lieu ou non
class _ActionConvoi {
  final String action;
  final String libelle;
  final IconData icone;
  final bool demandeLieu;

  const _ActionConvoi(this.action, this.libelle, this.icone, {this.demandeLieu = false});
}

class _EtapeTransitScreenState extends State<EtapeTransitScreen> {
  static const _actions = <String, List<_ActionConvoi>>{
    "ACHETE": [_ActionConvoi("transitaire", "Remis au transitaire", Icons.warehouse_outlined, demandeLieu: true)],
    "CHEZ_TRANSITAIRE": [_ActionConvoi("transit", "Départ en transit", Icons.local_shipping_outlined)],
    "EN_TRANSIT": [
      _ActionConvoi("arrivee", "Arrivé à destination", Icons.flag_outlined, demandeLieu: true),
      _ActionConvoi("douane", "Bloqué en douane", Icons.gavel_outlined, demandeLieu: true),
    ],
    "BLOQUE_DOUANE": [_ActionConvoi("transit", "Reprise du transit", Icons.play_arrow_rounded)],
  };

  bool _chargement = true;
  bool _action = false;
  String? _erreur;
  List<Convoi> _convois = [];

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
      final api = CourtierApiService.instance;
      final convois = await api.convois();
      if (!mounted) return;
      setState(() {
        _convois = convois;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e is ApiException ? e.messageComplet : "Impossible de charger les convois.";
      });
    }
  }

  Future<String?> _demander(String titre, {String label = "Lieu", String initial = ""}) async {
    final controller = TextEditingController(text: initial);
    final valeur = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text("Valider")),
        ],
      ),
    );
    controller.dispose();
    return valeur;
  }

  Future<void> _executer(Future<Convoi> Function() appel, String succes) async {
    setState(() => _action = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appel();
      messenger.showSnackBar(SnackBar(content: Text(succes), backgroundColor: AppTheme.success));
      await _charger();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.messageComplet : "Action impossible : $e"),
        backgroundColor: const Color(0xFFC0392B),
      ));
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  Future<void> _avancer(Convoi c, _ActionConvoi a) async {
    String? lieu;
    if (a.demandeLieu) {
      lieu = await _demander(a.libelle);
      if (lieu == null) return;
    }
    await _executer(() => CourtierApiService.instance.avancerConvoi(c.id, a.action, localisation: lieu),
        "${c.reference} : ${a.libelle.toLowerCase()}.");
  }

  Future<void> _jalonLibre(Convoi c) async {
    final statut = await _demander("Nouveau jalon", label: "Description (ex. Passage frontière)");
    if (statut == null || statut.isEmpty) return;
    if (!mounted) return;
    final lieu = await _demander("Lieu du jalon");
    if (lieu == null || lieu.isEmpty) return;
    await _executer(() => CourtierApiService.instance.ajouterEtape(c.id, statut: statut, localisation: lieu),
        "Jalon ajouté au convoi ${c.reference}.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Suivi des convois", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : _erreur != null || _convois.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(40),
                    children: [
                      Icon(_erreur != null ? Icons.error_outline : Icons.local_shipping_outlined,
                          size: 52, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        _erreur ??
                            "Aucun convoi. Créez-en un depuis l'acheminement d'un groupe qui a atteint son objectif.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _convois.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _carte(_convois[i]),
                  ),
      ),
    );
  }

  Widget _carte(Convoi c) {
    final actions = _actions[c.statut] ?? const [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A46321E), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.reference,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (c.statut == "BLOQUE_DOUANE" ? const Color(0xFFC0392B) : AppTheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(EtapeTransitScreen.libelleStatut(c.statut),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: c.statut == "BLOQUE_DOUANE" ? const Color(0xFFC0392B) : AppTheme.primary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Groupe n°${c.groupeId ?? '—'}${c.transporteur.isNotEmpty ? ' • ${c.transporteur}' : ''}",
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          ...c.evenements.reversed.map(_ligneEvenement),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...actions.map((a) => ElevatedButton.icon(
                    onPressed: _action ? null : () => _avancer(c, a),
                    icon: Icon(a.icone, size: 16),
                    label: Text(a.libelle),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  )),
              if (c.statut != "ARRIVE")
                OutlinedButton.icon(
                  onPressed: _action ? null : () => _jalonLibre(c),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                  label: const Text("Jalon"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ligneEvenement(EvenementConvoi e) {
    final d = e.date;
    final quand = d == null
        ? ""
        : "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} "
            "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 9, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${EtapeTransitScreen.libelleStatut(e.statut)} — ${e.localisation}",
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          Text(quand, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
