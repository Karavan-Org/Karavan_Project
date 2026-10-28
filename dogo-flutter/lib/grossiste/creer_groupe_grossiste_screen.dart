import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api/api_exception.dart';
import '../services/catalogue_api_service.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/image_produit.dart';
import '../widgets/partage_groupe.dart';

/// Création d'un groupe d'achat par le Grossiste sur l'un de ses produits, sans courtier :
/// il achemine lui-même la marchandise. Le prix de gros et le stock du produit pré-remplissent le
/// formulaire ; la soumission vaut confirmation du stock (RG-18), le groupe attend ensuite la publication
/// par un administrateur, et le grossiste peut partager son lien d'invitation.
class CreerGroupeGrossisteScreen extends StatefulWidget {
  /// Produit déjà choisi (ProduitVue du backend) ; sinon le grossiste le choisit dans son catalogue
  final Map<String, dynamic>? produit;

  const CreerGroupeGrossisteScreen({super.key, this.produit});

  @override
  State<CreerGroupeGrossisteScreen> createState() => _CreerGroupeGrossisteScreenState();
}

class _CreerGroupeGrossisteScreenState extends State<CreerGroupeGrossisteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _prixController = TextEditingController();
  final _minimumController = TextEditingController(text: '1');
  final _transportController = TextEditingController(text: '0');
  final _douaneController = TextEditingController(text: '0');
  final _autresController = TextEditingController(text: '0');
  final _delaiController = TextEditingController(text: '30');
  /// Politique d'annulation imposée par Karavan (RG-24) : affichée, jamais modifiable ni supprimable par le grossiste.
  /// Le backend l'applique de lui-même (GroupeService.POLITIQUE_ANNULATION_PLATEFORME).
  static const _politiqueAnnulation = "Annulation possible tant que l'objectif n'est pas atteint ; "
      "remboursement intégral si le groupe est annulé ou n'atteint pas son objectif.";

  List<Map<String, dynamic>> _produits = [];
  Map<String, dynamic>? _produit;
  DateTime _dateLimite = DateTime.now().add(const Duration(days: 14));
  bool _chargement = false;
  String? _erreurChargement;
  bool _envoi = false;
  bool _fraisVisibles = false;

  @override
  void initState() {
    super.initState();
    if (widget.produit != null) {
      _choisir(widget.produit!);
    } else {
      _chargerProduits();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titreController,
      _quantiteController,
      _prixController,
      _minimumController,
      _transportController,
      _douaneController,
      _autresController,
      _delaiController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerProduits() async {
    setState(() {
      _chargement = true;
      _erreurChargement = null;
    });
    try {
      final produits = await CatalogueApiService.instance.mesProduits();
      if (!mounted) return;
      setState(() {
        _produits = produits.map((p) => Map<String, dynamic>.from(p as Map)).toList();
        _chargement = false;
        if (_produits.length == 1) _choisir(_produits.first);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = e is ApiException ? e.messageComplet : '$e';
        _chargement = false;
      });
    }
  }

  /// Le prix de gros et le stock saisis à l'ajout du produit deviennent le prix et l'objectif du groupe
  void _choisir(Map<String, dynamic> p) {
    _produit = p;
    final nom = p['nom']?.toString() ?? '';
    _titreController.text = nom.isEmpty ? '' : "Achat groupé $nom";
    final stock = _stock(p);
    _quantiteController.text = stock > 0 ? '$stock' : '';
    final prix = p['prixGros'];
    final prixEntier = prix is num ? prix.round() : num.tryParse(prix?.toString() ?? '')?.round();
    _prixController.text = (prixEntier != null && prixEntier > 0) ? '$prixEntier' : '';
  }

  int _entier(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  int _stock(Map<String, dynamic> p) => CatalogueApiService.stockTotal(p);

  Future<void> _choisirDate() async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateLimite,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (choisie != null) setState(() => _dateLimite = DateTime(choisie.year, choisie.month, choisie.day, 23, 59));
  }

  Future<void> _creer() async {
    if (_produit == null) {
      _erreur("Choisissez d'abord un produit");
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _envoi = true);
    try {
      final service = GroupeApiService.instance;
      final brouillon = await service.creer(
        titre: _titreController.text,
        produitId: (_produit!['id'] as num).toInt(),
        quantiteCible: _entier(_quantiteController),
        dateLimite: _dateLimite,
        marchandise: _entier(_prixController),
        transport: _entier(_transportController),
        douane: _entier(_douaneController),
        autres: _entier(_autresController),
        delaiLivraisonJours: _entier(_delaiController),
        quantiteMinParCommercant: _entier(_minimumController),
      );
      final groupe = await service.soumettre(brouillon.id);
      CatalogueApiService.instance.signalerChangement();
      if (!mounted) return;
      setState(() => _envoi = false);
      await _succes(groupe);
      if (mounted) Navigator.of(context).pop(groupe);
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        _erreur(e is ApiException ? e.messageComplet : 'Création impossible : $e');
      }
    }
  }

  Future<void> _succes(GroupeResume groupe) async {
    final partager = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.check_circle_rounded, color: AppTheme.oliveProfond, size: 48),
        title: const Text("Groupe créé !", style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          "« ${groupe.titre} » (n° ${groupe.id}) attend sa publication par Karavan.\n\n"
          "Prix pour les commerçants : ${groupe.prixUnitaire} FCFA / pièce (frais de plateforme inclus).\n\n"
          "Partagez son lien pour que les commerçants le rejoignent.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Plus tard")),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text("Partager le lien"),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    if (partager == true && mounted) await afficherPartageGroupe(context, groupe);
  }

  void _erreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produit = _produit;
    final stock = produit == null ? 0 : _stock(produit);
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Créer un groupe d'achat", style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.couleurTexte(context))),
        backgroundColor: AppTheme.couleurCarte(context),
        foregroundColor: AppTheme.couleurTexte(context),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _titre("Produit"),
            const SizedBox(height: 10),
            if (produit != null && (widget.produit != null || _produits.length <= 1))
              _carteProduit(produit, selectionne: true)
            else
              ..._sectionProduits(),
            if (produit != null) ...[
              const SizedBox(height: 22),
              _titre("Votre groupe"),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titreController,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration("Titre du groupe"),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Donnez un titre au groupe" : null,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _champ(_quantiteController, "Objectif (pièces)", minimum: 1, maximum: stock > 0 ? stock : null,
                        aide: "Stock : $stock pcs"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _champ(_prixController, "Prix par pièce (FCFA)", minimum: 1, aide: "Prix de gros")),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _choisirDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: _decoration("Date limite"),
                        child: Text(
                          "${_dateLimite.day.toString().padLeft(2, '0')}/${_dateLimite.month.toString().padLeft(2, '0')}/${_dateLimite.year}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _champ(_minimumController, "Min. par achat", minimum: 1, aide: "pièces / commerçant",
                        // RG-27 : le minimum d'un commerçant ne peut pas dépasser l'objectif du groupe
                        verifier: (n) => n > _entier(_quantiteController) ? "≤ objectif" : null),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _sectionFrais(),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Vous acheminez vous-même la marchandise et signalez ses étapes à Karavan. Les frais de plateforme "
                  "sont ajoutés automatiquement au prix ; le groupe est visible des commerçants après sa publication.",
                  style: TextStyle(fontSize: 12, color: AppTheme.couleurTexte(context)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _envoi ? null : _creer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _envoi
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                      )
                    : const Text("Créer le groupe", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionFrais() {
    // Bloc dépliable simple : un ExpansionTile rognait les libellés flottants des champs
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _fraisVisibles = !_fraisVisibles),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text("Frais et conditions (facultatif)",
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context))),
                ),
                Icon(_fraisVisibles ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppTheme.couleurTexte(context)),
              ],
            ),
          ),
        ),
        if (_fraisVisibles) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _champ(_transportController, "Transport / pce")),
              const SizedBox(width: 12),
              Expanded(child: _champ(_douaneController, "Douane / pce")),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _champ(_autresController, "Autres / pce")),
              const SizedBox(width: 12),
              Expanded(child: _champ(_delaiController, "Livraison (jours)")),
            ],
          ),
          const SizedBox(height: 12),
          // Lecture seule : la politique d'annulation est fixée par la plateforme
          InputDecorator(
            decoration: _decoration("Politique d'annulation (fixée par Karavan)").copyWith(
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
            ),
            child: const Text(_politiqueAnnulation, style: TextStyle(fontSize: 13, height: 1.35)),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  List<Widget> _sectionProduits() {
    if (_chargement) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: AppTheme.olive)),
        ),
      ];
    }
    if (_erreurChargement != null) {
      return [
        Text("Catalogue indisponible : $_erreurChargement", style: const TextStyle(color: AppTheme.danger)),
        TextButton(onPressed: _chargerProduits, child: const Text("Réessayer")),
      ];
    }
    if (_produits.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.couleurCarte(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.couleurBordure(context)),
          ),
          child: Text(
            "Votre catalogue est vide : ajoutez d'abord un produit, puis créez son groupe d'achat.",
            style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
          ),
        ),
      ];
    }
    return [
      for (final p in _produits)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _carteProduit(p, selectionne: identical(_produit, p), onTap: () => setState(() => _choisir(p))),
        ),
    ];
  }

  Widget _carteProduit(Map<String, dynamic> p, {required bool selectionne, VoidCallback? onTap}) {
    return Material(
      color: AppTheme.couleurCarte(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selectionne ? AppTheme.primary : AppTheme.couleurBordure(context),
              width: selectionne ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56,
                  height: 56,
                  color: AppTheme.couleurFond(context),
                  child: imageProduit(p['photoUrl']?.toString() ?? '', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['nom']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.couleurTexte(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Stock : ${_stock(p)} pcs${p['prixGros'] != null ? ' • ${(p['prixGros'] as num).round()} FCFA / pce' : ''}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context)),
                    ),
                  ],
                ),
              ),
              Icon(
                selectionne ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selectionne ? AppTheme.primary : AppTheme.couleurBordure(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titre(String texte) =>
      Text(texte, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.couleurTexte(context)));

  InputDecoration _decoration(String label, {String? aide}) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.couleurTexteAttenue(context)),
        helperText: aide,
        filled: true,
        fillColor: AppTheme.couleurCarte(context),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.couleurBordure(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.couleurBordure(context))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _champ(TextEditingController c, String label,
      {int minimum = 0, int? maximum, String? aide, String? Function(int)? verifier}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _decoration(label, aide: aide),
      validator: (v) {
        final n = int.tryParse(v?.trim() ?? '');
        if (n == null) return "Obligatoire";
        if (n < minimum) return "Minimum $minimum";
        if (maximum != null && n > maximum) return "Maximum $maximum (stock)";
        return verifier?.call(n);
      },
    );
  }
}
