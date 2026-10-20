import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/courtier_api_service.dart';
import '../services/api/api_exception.dart';

/// Création d'un groupe d'achat par le Courtier (POST /api/groupes, RG-16 à RG-20).
///
/// Le courtier choisit un produit d'un grossiste actif, fixe la cible, la date limite et la grille unitaire
/// (marchandise, transport, douane, autres). Les frais de plateforme (RG-37) sont calculés par le backend.
/// Retourne `true` au `pop` quand un groupe a été créé.
class LancerConvoiScreen extends StatefulWidget {
  const LancerConvoiScreen({super.key});

  @override
  State<LancerConvoiScreen> createState() => _LancerConvoiScreenState();
}

class _LancerConvoiScreenState extends State<LancerConvoiScreen> {
  /// Taux indicatif des frais de plateforme (dogo.commission.taux) ; le montant final vient du backend
  static const double _tauxPlateformeIndicatif = 0.05;

  final _formKey = GlobalKey<FormState>();
  final _cibleController = TextEditingController();
  final _minController = TextEditingController(text: "1");
  final _marchandiseController = TextEditingController();
  final _transportController = TextEditingController(text: "0");
  final _douaneController = TextEditingController(text: "0");
  final _autresController = TextEditingController(text: "0");
  final _delaiController = TextEditingController();
  final _politiqueController = TextEditingController();

  List<ProduitDisponible> _produits = [];
  ProduitDisponible? _produit;
  DateTime _dateLimite = DateTime.now().add(const Duration(days: 14));
  bool _chargement = true;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerProduits();
    for (final c in [_marchandiseController, _transportController, _douaneController, _autresController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _cibleController,
      _minController,
      _marchandiseController,
      _transportController,
      _douaneController,
      _autresController,
      _delaiController,
      _politiqueController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerProduits() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final produits = await CourtierApiService.instance.produitsDisponibles();
      if (!mounted) return;
      setState(() {
        _produits = produits;
        _produit = produits.isNotEmpty ? produits.first : null;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e is ApiException ? e.messageComplet : "Impossible de charger le catalogue des grossistes.";
      });
    }
  }

  int _entier(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  int get _prixUnitaireEstime {
    final marchandise = _entier(_marchandiseController);
    final frais = (marchandise * _tauxPlateformeIndicatif).round();
    return marchandise + frais + _entier(_transportController) + _entier(_douaneController) + _entier(_autresController);
  }

  String _fcfa(int v) =>
      "${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA";

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateLimite,
      firstDate: maintenant.add(const Duration(days: 1)),
      lastDate: maintenant.add(const Duration(days: 365)),
    );
    if (choisie != null) {
      setState(() => _dateLimite = DateTime(choisie.year, choisie.month, choisie.day, 23, 59));
    }
  }

  Future<void> _creer({required bool soumettre}) async {
    if (_produit == null || !_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final delai = _delaiController.text.trim();
      var groupe = await CourtierApiService.instance.creerGroupe(
        produitId: _produit!.id,
        quantiteCible: _entier(_cibleController),
        dateLimite: _dateLimite,
        marchandise: _entier(_marchandiseController),
        transport: _entier(_transportController),
        douane: _entier(_douaneController),
        autres: _entier(_autresController),
        delaiLivraisonJours: delai.isEmpty ? null : int.tryParse(delai),
        politiqueAnnulation: _politiqueController.text.trim(),
        quantiteMinParCommercant: _entier(_minController),
      );
      if (soumettre) {
        groupe = await CourtierApiService.instance.soumettre(groupe.id);
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppTheme.success,
        content: Text(soumettre
            ? "Groupe n°${groupe.id} soumis : le grossiste puis l'administration doivent le valider."
            : "Brouillon n°${groupe.id} enregistré (prix unitaire : ${_fcfa(groupe.prixGroupe)})."),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFC0392B),
        content: Text(e is ApiException ? e.messageComplet : "Création impossible : $e"),
      ));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Créer un groupe d'achat", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.couleurTexte(context))),
        backgroundColor: AppTheme.couleurCarte(context),
        foregroundColor: AppTheme.couleurTexte(context),
        elevation: 0,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? _etatVide(_erreur!, Icons.error_outline)
              : _produits.isEmpty
                  ? _etatVide("Aucun produit disponible : les grossistes actifs n'ont encore rien publié.",
                      Icons.inventory_2_outlined)
                  : _formulaire(),
    );
  }

  Widget _etatVide(String message, IconData icone) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 52, color: AppTheme.primary),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _chargerProduits, child: const Text("Réessayer")),
          ],
        ),
      ),
    );
  }

  Widget _formulaire() {
    final d = _dateLimite;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.tertiary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Montants par unité, en FCFA. Les frais de plateforme Karavan sont ajoutés automatiquement.",
                    style: TextStyle(fontSize: 12.5, color: AppTheme.couleurTexte(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _titre("Produit"),
          DropdownButtonFormField<ProduitDisponible>(
            initialValue: _produit,
            isExpanded: true,
            decoration: _deco("Produit d'un grossiste actif", Icons.inventory_2_outlined),
            items: _produits
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                        "${p.nom}${p.grossisteNom.isNotEmpty ? ' — ${p.grossisteNom}' : ''}",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (p) => setState(() => _produit = p),
          ),
          if (_produit != null && _produit!.variantes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Variantes : ${_produit!.variantes.map((v) => v.libelle).join(', ')}",
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 20),
          _titre("Objectif"),
          Row(
            children: [
              Expanded(child: _champEntier(_cibleController, "Quantité cible", Icons.flag_outlined, min: 1)),
              const SizedBox(width: 12),
              Expanded(child: _champEntier(_minController, "Min. / commerçant", Icons.person_outline, min: 1)),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _choisirDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: _deco("Date limite de participation", Icons.event_outlined),
              child: Text(
                "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _titre("Grille tarifaire unitaire"),
          _champEntier(_marchandiseController, "Prix marchandise", Icons.sell_outlined, min: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _champEntier(_transportController, "Transport", Icons.local_shipping_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _champEntier(_douaneController, "Douane", Icons.gavel_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          _champEntier(_autresController, "Autres frais", Icons.more_horiz),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.couleurBordure(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text("Prix unitaire estimé (frais Karavan 5 % inclus)",
                      style: TextStyle(fontSize: 12.5, color: AppTheme.couleurTexteAttenue(context))),
                ),
                Text(_fcfa(_prixUnitaireEstime),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _titre("Conditions (facultatif)"),
          _champEntier(_delaiController, "Délai de livraison (jours)", Icons.schedule_outlined, obligatoire: false),
          const SizedBox(height: 12),
          TextFormField(
            controller: _politiqueController,
            maxLines: 2,
            decoration: _deco("Politique d'annulation", Icons.policy_outlined),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _envoi ? null : () => _creer(soumettre: true),
            icon: _envoi
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text("Créer et soumettre à validation"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _envoi ? null : () => _creer(soumettre: false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text("Enregistrer comme brouillon"),
          ),
        ],
      ),
    );
  }

  Widget _titre(String texte) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texte, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.couleurTexte(context))),
      );

  InputDecoration _deco(String label, IconData icone) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone, color: AppTheme.primary),
        filled: true,
        fillColor: AppTheme.couleurCarte(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.couleurBordure(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.couleurBordure(context))),
      );

  Widget _champEntier(TextEditingController c, String label, IconData icone, {int min = 0, bool obligatoire = true}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _deco(label, icone),
      validator: (v) {
        final texte = v?.trim() ?? '';
        if (texte.isEmpty) return obligatoire ? "Obligatoire" : null;
        final n = int.tryParse(texte);
        if (n == null || n < min) return "Minimum $min";
        if (c == _minController && n > _entier(_cibleController)) return "≤ cible";
        return null;
      },
    );
  }
}
