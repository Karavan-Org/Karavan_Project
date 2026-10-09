import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/image_produit.dart';

/// Création d'un groupe d'achat par le Courtier (RG-16, RG-17) : il choisit un produit dans le catalogue
/// des grossistes validés, fixe l'objectif et la grille de coûts unitaires, puis envoie le groupe au grossiste
/// pour qu'il confirme son stock (RG-18). Les frais de plateforme sont calculés par le backend (RG-37).
class CreerGroupeCourtierScreen extends StatefulWidget {
  const CreerGroupeCourtierScreen({super.key});

  @override
  State<CreerGroupeCourtierScreen> createState() => _CreerGroupeCourtierScreenState();
}

class _CreerGroupeCourtierScreenState extends State<CreerGroupeCourtierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantiteController = TextEditingController();
  final _marchandiseController = TextEditingController();
  final _transportController = TextEditingController(text: '0');
  final _douaneController = TextEditingController(text: '0');
  final _autresController = TextEditingController(text: '0');
  final _delaiController = TextEditingController(text: '30');
  final _minimumController = TextEditingController(text: '1');
  final _politiqueController = TextEditingController(text: "Annulation possible tant que l'objectif n'est pas atteint");

  List<Map<String, dynamic>> _produits = [];
  Map<String, dynamic>? _produit;
  DateTime _dateLimite = DateTime.now().add(const Duration(days: 7));
  bool _chargement = true;
  String? _erreurChargement;
  bool _envoi = false;

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
      _quantiteController,
      _marchandiseController,
      _transportController,
      _douaneController,
      _autresController,
      _delaiController,
      _minimumController,
      _politiqueController,
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
      final produits = await GroupeApiService.instance.produitsDisponibles();
      if (!mounted) return;
      setState(() {
        _produits = produits;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = e is ApiException ? e.messageComplet : '$e';
        _chargement = false;
      });
    }
  }

  int _entier(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  int get _coutUnitaireSaisi =>
      _entier(_marchandiseController) + _entier(_transportController) + _entier(_douaneController) + _entier(_autresController);

  int _stock(Map<String, dynamic> p) =>
      ((p['variantes'] as List?) ?? []).fold<int>(0, (t, v) => t + (((v as Map)['qteDisponible'] as num?) ?? 0).toInt());

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
      final groupe = await GroupeApiService.instance.creer(
        produitId: (_produit!['id'] as num).toInt(),
        quantiteCible: _entier(_quantiteController),
        dateLimite: _dateLimite,
        marchandise: _entier(_marchandiseController),
        transport: _entier(_transportController),
        douane: _entier(_douaneController),
        autres: _entier(_autresController),
        delaiLivraisonJours: _entier(_delaiController),
        politiqueAnnulation: _politiqueController.text.trim(),
        quantiteMinParCommercant: _entier(_minimumController),
      );
      final soumis = await GroupeApiService.instance.soumettre(groupe.id);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Groupe créé", style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            "Le groupe n° ${soumis.id} (${soumis.produitNom}) est envoyé à ${soumis.grossisteNom}, "
            "qui doit confirmer son stock. Il sera ensuite publié par un administrateur dɔgɔ, puis visible "
            "par les commerçants.\n\nPrix unitaire calculé : ${soumis.prixUnitaire} FCFA (frais de plateforme inclus).",
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Compris"))],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _erreur(e is ApiException ? e.messageComplet : 'Création impossible : $e');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _erreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFC0392B), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Créer un groupe d'achat", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _titre("1. Produit du grossiste"),
            const SizedBox(height: 10),
            ..._sectionProduits(),
            const SizedBox(height: 24),
            _titre("2. Objectif"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _champ(_quantiteController, "Quantité cible (pièces)", obligatoire: true, minimum: 1)),
                const SizedBox(width: 12),
                Expanded(child: _champ(_minimumController, "Minimum par commerçant", obligatoire: true, minimum: 1)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
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
                Expanded(child: _champ(_delaiController, "Délai de livraison (jours)", obligatoire: true)),
              ],
            ),
            const SizedBox(height: 24),
            _titre("3. Coûts par pièce (FCFA)"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _champ(_marchandiseController, "Marchandise", obligatoire: true, minimum: 1)),
                const SizedBox(width: 12),
                Expanded(child: _champ(_transportController, "Transport", obligatoire: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _champ(_douaneController, "Douane", obligatoire: true)),
                const SizedBox(width: 12),
                Expanded(child: _champ(_autresController, "Autres frais", obligatoire: true)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Sous-total saisi : $_coutUnitaireSaisi FCFA / pièce. Les frais de plateforme dɔgɔ sont ajoutés "
                "automatiquement : le prix final s'affiche après la création.",
                style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
              ),
            ),
            const SizedBox(height: 24),
            _titre("4. Conditions"),
            const SizedBox(height: 10),
            TextFormField(
              controller: _politiqueController,
              maxLines: 2,
              decoration: _decoration("Politique d'annulation"),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _envoi || _produit == null ? null : _creer,
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
                  : const Text("Créer et envoyer au grossiste", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sectionProduits() {
    if (_chargement) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ),
      ];
    }
    if (_erreurChargement != null) {
      return [
        Text("Catalogue indisponible : $_erreurChargement", style: const TextStyle(color: Color(0xFFC0392B))),
        TextButton(onPressed: _chargerProduits, child: const Text("Réessayer")),
      ];
    }
    if (_produits.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const Text(
            "Aucun produit disponible pour l'instant. Un grossiste dont le dossier est validé doit d'abord "
            "ajouter un produit à son catalogue.",
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ),
        TextButton(onPressed: _chargerProduits, child: const Text("Actualiser")),
      ];
    }
    return [
      for (final p in _produits)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _produit = p),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: identical(_produit, p) ? AppTheme.primary : const Color(0xFFEDE7E1),
                    width: identical(_produit, p) ? 2 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFFF7F2EB),
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
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${p['grossisteNom'] ?? ''} • Stock : ${_stock(p)} pcs",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      identical(_produit, p) ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: identical(_produit, p) ? AppTheme.primary : const Color(0xFFC7B8AA),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _titre(String texte) =>
      Text(texte, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark));

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _champ(TextEditingController c, String label, {bool obligatoire = false, int minimum = 0}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _decoration(label),
      validator: (v) {
        final n = int.tryParse(v?.trim() ?? '');
        if (obligatoire && n == null) return "Obligatoire";
        if (n != null && n < minimum) return "Minimum $minimum";
        return null;
      },
    );
  }
}
