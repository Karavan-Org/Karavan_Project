import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/convoi_api_service.dart';
import '../services/courtier_api_service.dart' show CourtierApiService, PointRetrait;
import '../services/groupe_api_service.dart';
import '../services/visibilite_ecran.dart';
import '../theme/app_theme.dart';
import '../widgets/image_produit.dart';
import '../widgets/tab_navigation_scope.dart';
import 'scanner_retrait_screen.dart';

/// Acheminement du courtier, en temps réel : chaque groupe à traiter avec sa prochaine étape (préparer les
/// commandes, expédier le lot, ouvrir le convoi, déposer au point de retrait), puis les convois en cours avec
/// leurs étapes officielles et leur journal, et les convois arrivés. Chaque action passe par le serveur, qui valide la
/// transition et notifie les commerçants, le grossiste et le porteur du groupe.
class GestionConvoiScreen extends StatefulWidget {
  const GestionConvoiScreen({super.key});

  @override
  State<GestionConvoiScreen> createState() => _GestionConvoiScreenState();
}

class _GestionConvoiScreenState extends State<GestionConvoiScreen> {
  List<Convoi> _convois = [];
  Map<int, GroupeResume> _groupes = {};
  /// Statuts des commandes des groupes où le courtier a une étape à franchir (StatutCommande du backend)
  Map<int, List<String>> _commandes = {};
  bool _chargement = true;
  String? _erreur;
  int? _actionEnCours; // convoi ou groupe dont une action attend le serveur
  Timer? _actualisation;

  @override
  void initState() {
    super.initState();
    _charger();
    // Un administrateur peut aussi faire avancer un convoi : relecture discrète tant que l'écran est vu
    _actualisation = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && ecranVisible(context) && _actionEnCours == null) _charger(silencieux: true);
    });
  }

  @override
  void dispose() {
    _actualisation?.cancel();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    if (!silencieux) {
      setState(() {
        _chargement = _convois.isEmpty && _groupes.isEmpty;
        _erreur = null;
      });
    }
    try {
      final resultats = await Future.wait([
        ConvoiApiService.instance.lister(),
        GroupeApiService.instance.mesGroupesCourtier(),
      ]);
      final groupes = resultats[1] as List<GroupeResume>;
      // Les commandes disent où en est la préparation (groupe à l'objectif) ou la réception (groupe livré)
      final aSuivre = groupes.where((g) => g.statut == 'OBJECTIF_ATTEINT' || g.statut == 'LIVRE').toList();
      final commandes = await Future.wait(aSuivre.map((g) => CourtierApiService.instance
          .commandesDuGroupe('${g.id}')
          .then((l) => l.map((c) => c['statut']?.toString() ?? '').where((s) => s != 'ANNULEE').toList())
          .catchError((_) => <String>[])));
      if (!mounted) return;
      setState(() {
        _convois = resultats[0] as List<Convoi>;
        _groupes = {for (final g in groupes) g.id: g};
        _commandes = {for (final (i, g) in aSuivre.indexed) g.id: commandes[i]};
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted || silencieux) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : "Impossible de charger vos convois.";
        _chargement = false;
      });
    }
  }

  /// Groupes où le courtier a une étape à franchir, avec sa description et ses actions
  List<(GroupeResume, String, List<Widget>)> get _aTraiter {
    final avecConvoi = _convois.map((c) => c.groupeId).toSet();
    final occupe = _actionEnCours != null;
    final api = CourtierApiService.instance;
    final resultat = <(GroupeResume, String, List<Widget>)>[];
    String pluriel(int n, String mot) => "$n $mot${n > 1 ? 's' : ''}";
    for (final g in _groupes.values) {
      final statuts = _commandes[g.id] ?? const <String>[];
      final ouvrirConvoi = !avecConvoi.contains(g.id)
          ? [OutlinedButton(onPressed: occupe ? null : () => _ouvrirConvoi(g), child: const Text("Ouvrir le convoi"))]
          : const <Widget>[];
      switch (g.statut) {
        case 'OBJECTIF_ATTEINT':
          final aPreparer = statuts.where((s) => s == 'CREEE').length;
          resultat.add(aPreparer > 0
              ? (g, "Objectif atteint : ${pluriel(aPreparer, 'commande')} à préparer", [
                  FilledButton(
                    onPressed: occupe
                        ? null
                        : () => _executer(-g.id, () => api.preparer('${g.id}'), "Commandes marquées comme préparées."),
                    child: const Text("Commandes préparées"),
                  ),
                  ...ouvrirConvoi,
                ])
              : (g, "Lot prêt : ${pluriel(statuts.length, 'commande')} à expédier", [
                  FilledButton(
                    onPressed: occupe
                        ? null
                        : () => _executer(-g.id, () => api.expedier('${g.id}'), "Lot expédié : les commerçants sont prévenus."),
                    child: const Text("Expédier le lot"),
                  ),
                  ...ouvrirConvoi,
                ]));
        case 'EN_EXPEDITION' when ouvrirConvoi.isNotEmpty:
          resultat.add((g, "Lot expédié : ouvrez son convoi pour en publier le suivi", ouvrirConvoi));
        case 'LIVRE' when statuts.contains('ARRIVEE'):
          resultat.add((g, "Colis réceptionnés au dépôt : choisissez leur point de retrait", [
            FilledButton(onPressed: occupe ? null : () => _deposerAuPoint(g), child: const Text("Point de retrait")),
          ]));
        case 'LIVRE' when statuts.contains('EXPEDIEE'):
          resultat.add((g, "Arrivé : en attente de la réception au dépôt par l'équipe Karavan", const <Widget>[]));
      }
    }
    return resultat;
  }

  /// Le lot reçu au dépôt est affecté à un point de retrait : les codes de retrait des commerçants sont générés
  Future<void> _deposerAuPoint(GroupeResume g) async {
    List<PointRetrait> points;
    try {
      points = await CourtierApiService.instance.pointsRetrait();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(e is ApiException ? e.messageComplet : "Points de retrait indisponibles."),
        ));
      }
      return;
    }
    if (!mounted) return;
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun point de retrait n'est encore configuré par l'administration.")));
      return;
    }
    final choisi = await showModalBottomSheet<PointRetrait>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 12), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text("Point de retrait des colis", style: AppTheme.styleTitreMoyen(ctx)),
          ),
          for (final p in points)
            ListTile(
              leading: const Icon(Icons.storefront_rounded),
              title: Text(p.nom),
              subtitle: Text([p.adresse, p.quartier].where((s) => s.isNotEmpty).join(" • ")),
              onTap: () => Navigator.pop(ctx, p),
            ),
        ]),
      ),
    );
    if (choisi == null) return;
    await _executer(-g.id, () => CourtierApiService.instance.confirmerArriveeAuPoint('${g.id}', choisi.id),
        "Colis disponibles chez « ${choisi.nom} » : les codes de retrait sont envoyés aux commerçants.");
  }

  Future<void> _executer(int cle, Future<Object?> Function() action, String succes) async {
    setState(() => _actionEnCours = cle);
    try {
      await action();
      await _charger(silencieux: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(succes)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(e is ApiException ? e.messageComplet : "Action impossible : $e"),
        ));
      }
    } finally {
      if (mounted) setState(() => _actionEnCours = null);
    }
  }

  Future<void> _ouvrirConvoi(GroupeResume g) async {
    final reference = TextEditingController(text: "CV-${g.id}-${DateTime.now().millisecondsSinceEpoch % 100000}");
    final transporteur = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ouvrir le convoi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(g.titre.isNotEmpty ? g.titre : g.produitNom, style: AppTheme.styleCorpsAttenue(ctx)),
            const SizedBox(height: 12),
            TextField(controller: reference, decoration: const InputDecoration(labelText: "Référence du convoi")),
            const SizedBox(height: 10),
            TextField(
              controller: transporteur,
              decoration: const InputDecoration(labelText: "Transporteur (compagnie, vol, navire…)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Ouvrir")),
        ],
      ),
    );
    if (ok != true || reference.text.trim().isEmpty) return;
    await _executer(
      -g.id,
      () => ConvoiApiService.instance
          .creer(groupeId: g.id, reference: reference.text.trim(), transporteur: transporteur.text),
      "Convoi ouvert : le suivi est visible par les commerçants.",
    );
  }

  /// Demande un lieu (facultatif ou obligatoire) avant une étape
  Future<String?> _demanderLieu(String titre, {String? suggestion, bool obligatoire = false}) async {
    final lieu = TextEditingController(text: suggestion ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: lieu,
          autofocus: true,
          decoration: InputDecoration(labelText: obligatoire ? "Lieu" : "Lieu (facultatif)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirmer")),
        ],
      ),
    );
    if (ok != true) return null;
    if (obligatoire && lieu.text.trim().isEmpty) return null;
    return lieu.text.trim();
  }

  Future<void> _ajouterEvenement(Convoi c) async {
    final statut = TextEditingController();
    final lieu = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajouter un point de passage"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: statut,
            autofocus: true,
            decoration: const InputDecoration(labelText: "Événement (ex. : escale, chargement)"),
          ),
          const SizedBox(height: 10),
          TextField(controller: lieu, decoration: const InputDecoration(labelText: "Lieu")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Publier")),
        ],
      ),
    );
    if (ok != true || statut.text.trim().isEmpty || lieu.text.trim().isEmpty) return;
    await _executer(
      c.id,
      () => ConvoiApiService.instance
          .ajouterEvenement(c.id, statut: statut.text.trim(), localisation: lieu.text.trim()),
      "Point de passage publié et notifié aux commerçants.",
    );
  }

  /// Actions autorisées par la machine d'états du serveur pour le statut courant
  List<Widget> _actions(Convoi c) {
    final api = ConvoiApiService.instance;
    Widget bouton(String libelle, IconData icone, Future<void> Function() onTap, {bool principal = true}) =>
        principal
            ? FilledButton.icon(onPressed: _actionEnCours != null ? null : onTap, icon: Icon(icone, size: 18), label: Text(libelle))
            : OutlinedButton.icon(
                onPressed: _actionEnCours != null ? null : onTap,
                icon: Icon(icone, size: 18),
                label: Text(libelle),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              );
    return switch (c.statut) {
      'ACHETE' => [
          bouton("Remis au transitaire", Icons.warehouse_rounded, () async {
            final lieu = await _demanderLieu("Remise au transitaire", suggestion: "Entrepôt du transitaire");
            if (lieu != null) {
              await _executer(c.id, () => api.remettreAuTransitaire(c.id, localisation: lieu),
                  "Marchandises remises au transitaire.");
            }
          }),
        ],
      'CHEZ_TRANSITAIRE' => [
          bouton("Lancer le transit", Icons.flight_takeoff_rounded,
              () => _executer(c.id, () => api.lancerTransit(c.id), "Convoi en transit.")),
        ],
      'EN_TRANSIT' => [
          bouton("Arrivé à destination", Icons.flag_rounded, () async {
            final lieu = await _demanderLieu("Arrivée du convoi", suggestion: "Bamako");
            if (lieu != null) {
              await _executer(c.id, () => api.marquerArrive(c.id, localisation: lieu), "Arrivée enregistrée.");
            }
          }),
          bouton("Contrôle douanier", Icons.policy_rounded, () async {
            final lieu = await _demanderLieu("Contrôle douanier", suggestion: "Poste frontalier");
            if (lieu != null) {
              await _executer(c.id, () => api.declarerDouane(c.id, localisation: lieu), "Contrôle douanier déclaré.");
            }
          }, principal: false),
        ],
      'BLOQUE_DOUANE' => [
          bouton("Reprendre le transit", Icons.play_arrow_rounded,
              () => _executer(c.id, () => api.lancerTransit(c.id), "Transit repris.")),
        ],
      _ => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final enCours = _convois.where((c) => !c.estArrive).toList();
    final arrives = _convois.where((c) => c.estArrive).toList();
    final aTraiter = _aTraiter;

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),
        title: const Text("Mes convois"),
        actions: [
          IconButton(
            tooltip: "Scanner un retrait",
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerRetraitScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: _chargement
            ? ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())])
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  if (_erreur != null) _Bandeau(message: _erreur!, onReessayer: _charger),
                  if (aTraiter.isNotEmpty) ...[
                    _titre("À traiter (${aTraiter.length})"),
                    for (final (g, etape, actions) in aTraiter)
                      _CarteGroupeATraiter(groupe: g, etape: etape, actions: actions, occupe: _actionEnCours == -g.id),
                    const SizedBox(height: 12),
                  ],
                  _titre("En cours (${enCours.length})"),
                  if (enCours.isEmpty)
                    _Vide(
                      icone: Icons.local_shipping_outlined,
                      texte: aTraiter.isEmpty
                          ? "Aucun convoi en cours. Il s'ouvre dès qu'un de vos groupes atteint son objectif."
                          : "Ouvrez le convoi d'un groupe à traiter pour démarrer son suivi.",
                    ),
                  for (final c in enCours)
                    _CarteConvoi(
                      convoi: c,
                      groupe: _groupes[c.groupeId],
                      occupe: _actionEnCours == c.id,
                      actions: _actions(c),
                      onAjouterEvenement: _actionEnCours != null ? null : () => _ajouterEvenement(c),
                    ),
                  if (arrives.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _titre("Arrivés (${arrives.length})"),
                    for (final c in arrives)
                      _CarteConvoi(convoi: c, groupe: _groupes[c.groupeId], occupe: false, actions: const []),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _titre(String texte) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(texte, style: AppTheme.styleTitreMoyen(context)),
      );
}

class _CarteGroupeATraiter extends StatelessWidget {
  final GroupeResume groupe;
  final String etape;
  final List<Widget> actions;
  final bool occupe;

  const _CarteGroupeATraiter({required this.groupe, required this.etape, required this.actions, required this.occupe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 52, height: 52, child: imageProduit(groupe.photoUrl ?? '', fit: BoxFit.cover)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(groupe.titre.isNotEmpty ? groupe.titre : groupe.produitNom,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.styleTitrePetit(context)),
              const SizedBox(height: 2),
              Text("${groupe.quantiteConfirmee} pièces confirmées • ${groupe.grossisteNom}",
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.styleCorpsAttenue(context)),
              const SizedBox(height: 6),
              Text(etape, style: AppTheme.styleCorps(context, graisse: FontWeight.w600)),
              if (occupe)
                const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator())
              else if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CarteConvoi extends StatelessWidget {
  final Convoi convoi;
  final GroupeResume? groupe;
  final bool occupe;
  final List<Widget> actions;
  final VoidCallback? onAjouterEvenement;

  const _CarteConvoi({
    required this.convoi,
    required this.groupe,
    required this.occupe,
    required this.actions,
    this.onAjouterEvenement,
  });

  static String _date(DateTime? d) {
    if (d == null) return '';
    String deux(int n) => n.toString().padLeft(2, '0');
    return "${deux(d.day)}/${deux(d.month)} ${deux(d.hour)}h${deux(d.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    final douane = convoi.statut == 'BLOQUE_DOUANE';
    final couleurStatut = convoi.estArrive
        ? AppTheme.couleurSucces(context)
        : douane
            ? AppTheme.couleurAttention(context)
            : AppTheme.couleurAccent(context);
    final dernier = convoi.dernierEvenement;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  groupe != null ? (groupe!.titre.isNotEmpty ? groupe!.titre : groupe!.produitNom) : "Groupe #${convoi.groupeId}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.styleTitreMoyen(context),
                ),
                const SizedBox(height: 2),
                Text(
                  [convoi.reference, if (convoi.transporteur?.isNotEmpty == true) convoi.transporteur!].join(" • "),
                  style: AppTheme.styleCorpsAttenue(context),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: couleurStatut.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(convoi.libelleStatut,
                  style: AppTheme.styleEtiquette(context, couleur: couleurStatut, graisse: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 14),
          _Etapes(rang: convoi.rang, douane: douane),
          if (dernier != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.place_outlined, size: 16, color: AppTheme.couleurTexteAttenue(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text("${dernier.libelle} — ${dernier.localisation}",
                    style: AppTheme.styleCorps(context, graisse: FontWeight.w600)),
              ),
              Text(_date(dernier.date), style: AppTheme.styleCorpsAttenue(context, taille: 11)),
            ]),
          ],
          if (convoi.evenements.length > 1)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text("Journal du convoi (${convoi.evenements.length})", style: AppTheme.styleEtiquette(context)),
                children: [
                  for (final e in convoi.evenements.reversed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.circle, size: 8),
                      title: Text(e.libelle),
                      subtitle: Text(e.localisation),
                      trailing: Text(_date(e.date), style: AppTheme.styleCorpsAttenue(context, taille: 11)),
                    ),
                ],
              ),
            ),
          if (occupe)
            const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator())
          else if (actions.isNotEmpty || onAjouterEvenement != null) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              ...actions,
              if (onAjouterEvenement != null)
                TextButton.icon(
                  onPressed: onAjouterEvenement,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text("Point de passage"),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Les quatre étapes officielles du convoi ; le contrôle douanier marque la phase de transit en attention
class _Etapes extends StatelessWidget {
  final int rang;
  final bool douane;

  const _Etapes({required this.rang, required this.douane});

  static const _libelles = ["Ouvert", "Transitaire", "Transit", "Arrivé"];

  @override
  Widget build(BuildContext context) {
    final fait = AppTheme.couleurSucces(context);
    final attente = AppTheme.couleurBordureForte(context);
    return Row(children: [
      for (var i = 0; i < _libelles.length; i++) ...[
        Expanded(
          child: Column(children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < rang || (i == rang && i == 3)
                    ? fait
                    : i == rang
                        ? (douane ? AppTheme.couleurAttention(context) : AppTheme.couleurAccent(context))
                        : attente,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            Text(_libelles[i], style: AppTheme.styleCorpsAttenue(context, taille: 10.5)),
          ]),
        ),
        if (i < _libelles.length - 1) const SizedBox(width: 6),
      ],
    ]);
  }
}

class _Bandeau extends StatelessWidget {
  final String message;
  final VoidCallback onReessayer;

  const _Bandeau({required this.message, required this.onReessayer});

  @override
  Widget build(BuildContext context) => Card(
        color: AppTheme.estSombre(context) ? AppTheme.darkDangerSurface : AppTheme.dangerClair,
        child: ListTile(
          leading: const Icon(Icons.cloud_off_rounded, color: AppTheme.danger),
          title: Text(message),
          trailing: TextButton(onPressed: onReessayer, child: const Text("Réessayer")),
        ),
      );
}

class _Vide extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Vide({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(children: [
            Icon(icone, size: 38, color: AppTheme.couleurTexteAttenue(context)),
            const SizedBox(height: 10),
            Text(texte, textAlign: TextAlign.center, style: AppTheme.styleCorpsAttenue(context, taille: 12.5)),
          ]),
        ),
      );
}
