import '../widgets/image_produit.dart';
import '../widgets/drapeau_pays_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/groupe_api_service.dart';
import 'campagne_model.dart';
import 'favoris_service.dart';
import 'rejoindre_groupe_screen.dart';
import '../services/visibilite_ecran.dart';
import '../widgets/tab_navigation_scope.dart';

/// Fiche détaillée d'une campagne d'achat groupé pour le Commerçant
class FicheCampagneScreen extends StatefulWidget {
  final String id;
  final String titre;
  final String sousTitre;
  final String imagePath;
  final int prixGroupe;
  final int prixPublic;
  final int quantiteActuelle;
  final int quantiteObjectif;
  final String categorie;
  final String paysOrigine;
  final String courtierNom;
  final String tempsRestant;
  final GroupeCampagneModel? groupe;
  final List<VarianteGroupeModel>? variantes;
  final int? quantiteMin;

  const FicheCampagneScreen({
    super.key,
    this.id = "",
    this.titre = "",
    this.sousTitre = "",
    this.imagePath = "",
    this.prixGroupe = 0,
    this.prixPublic = 0,
    this.quantiteActuelle = 0,
    this.quantiteObjectif = 1,
    this.categorie = "",
    this.paysOrigine = "",
    this.courtierNom = "",
    this.tempsRestant = "",
    this.groupe,
    this.variantes,
    this.quantiteMin,
  });

  factory FicheCampagneScreen.depuis(GroupeCampagneModel groupe) {
    return FicheCampagneScreen(
      id: groupe.id,
      titre: groupe.titre,
      sousTitre: groupe.sousTitre,
      imagePath: groupe.imagePath,
      prixGroupe: groupe.prixGroupe,
      prixPublic: groupe.prixPublic,
      quantiteActuelle: groupe.quantiteActuelle,
      quantiteObjectif: groupe.quantiteObjectif,
      categorie: groupe.categorie,
      paysOrigine: groupe.paysOrigine,
      courtierNom: groupe.courtierNom,
      groupe: groupe,
    );
  }

  @override
  State<FicheCampagneScreen> createState() => _FicheCampagneScreenState();
}

class _FicheCampagneScreenState extends State<FicheCampagneScreen> with ActualisationAutomatique<FicheCampagneScreen> {
  final TextEditingController _quantiteController = TextEditingController();
  late int _quantite;
  late int _quantiteMin;
  late int _quantiteActuelle;
  late int _quantiteObjectif;
  late int _quantiteRestante;
  int _quantiteDejaCommandee = 0;
  List<VarianteGroupeModel> _variantes = [];
  VarianteGroupeModel? _varianteSelectionnee;

  /// Données vivantes : relues en arrière-plan tant que l'écran est affiché
  @override
  Future<void> actualiserEnSilence() async {
    await Future.wait([
      _chargerDetailsGroupe(),
      _verifierParticipationsExistantes(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    demarrerActualisation();
    _initialiserVariantesEtQuantite();
    _verifierParticipationsExistantes();
  }

  Future<void> _verifierParticipationsExistantes() async {
    final gid = int.tryParse(widget.id.isNotEmpty ? widget.id : (widget.groupe?.id ?? ''));
    if (gid == null) return;
    try {
      final mesPart = await GroupeApiService.instance.mesParticipations();
      final pourCeGroupe = mesPart.where((p) => p.groupeId == gid && p.statut != 'ANNULEE' && p.statut != 'EXPIREE');
      final total = pourCeGroupe.fold<int>(0, (acc, p) => acc + p.quantite);
      if (mounted) setState(() => _quantiteDejaCommandee = total);
    } catch (_) {}
  }

  void _initialiserVariantesEtQuantite() {
    _quantiteMin = widget.quantiteMin ?? widget.groupe?.quantiteMinParCommercant ?? 1;
    if (_quantiteMin <= 0) _quantiteMin = 1;
    _quantite = _quantiteMin;

    _quantiteActuelle = widget.quantiteActuelle > 0
        ? widget.quantiteActuelle
        : (widget.groupe?.quantiteActuelle ?? 0);
    _quantiteObjectif = widget.quantiteObjectif > 0
        ? widget.quantiteObjectif
        : (widget.groupe?.quantiteObjectif ?? 1);
    if (_quantiteObjectif <= 0) _quantiteObjectif = 1;
    _quantiteRestante = widget.groupe?.quantiteRestante ??
        (_quantiteObjectif - _quantiteActuelle).clamp(0, _quantiteObjectif).toInt();
    _quantite = _quantiteMax >= _quantiteMin ? _quantiteMin : 0;
    _quantiteController.text = '$_quantite';

    if (widget.variantes != null && widget.variantes!.isNotEmpty) {
      _variantes = List.from(widget.variantes!);
    } else if (widget.groupe != null && widget.groupe!.variantes.isNotEmpty) {
      _variantes = List.from(widget.groupe!.variantes);
    }

    if (_variantes.isNotEmpty) {
      _varianteSelectionnee = _variantes.first;
    }

    _chargerDetailsGroupe();
  }

  Future<void> _chargerDetailsGroupe() async {
    final gid = widget.id.isNotEmpty ? widget.id : widget.groupe?.id;
    if (gid == null || gid.isEmpty) return;

    try {
      final detail = await GroupeApiService.instance.detail(gid);
      if (!mounted) return;
      setState(() {
        if (detail.variantes.isNotEmpty) {
          _variantes = detail.variantes;
          if (_varianteSelectionnee == null ||
              !_variantes.any((v) => v.id == _varianteSelectionnee!.id)) {
            _varianteSelectionnee = _variantes.first;
          }
        }
        if (detail.quantiteMinParCommercant > 0) {
          _quantiteMin = detail.quantiteMinParCommercant;
          if (_quantite < _quantiteMin) {
            _quantite = _quantiteMin;
          }
        }
        if (detail.quantiteObjectif > 0) {
          _quantiteObjectif = detail.quantiteObjectif;
        }
        _quantiteActuelle = detail.quantiteActuelle;
        _quantiteRestante = detail.quantiteRestante;
        if (_quantiteMax >= _quantiteMin) {
          _quantite = _quantite.clamp(_quantiteMin, _quantiteMax).toInt();
        } else {
          _quantite = 0;
        }
        _quantiteController.text = '$_quantite';
      });
    } catch (_) {}
  }

  double get _pourcentage =>
      _quantiteObjectif > 0 ? (_quantiteActuelle / _quantiteObjectif).clamp(0.0, 1.0) : 0.0;

  int get _quantiteMax {
    return _quantiteRestante.clamp(0, _quantiteObjectif).toInt();
  }

  void _definirQuantite(int quantite) {
    final valeur = quantite.clamp(0, _quantiteMax).toInt();
    setState(() {
      _quantite = valeur;
      _quantiteController.value = TextEditingValue(
        text: '$valeur',
        selection: TextSelection.collapsed(offset: '$valeur'.length),
      );
    });
  }

  void _terminerSaisieQuantite() {
    final saisie = int.tryParse(_quantiteController.text) ?? _quantiteMin;
    final valeur = _quantiteMax >= _quantiteMin
        ? saisie.clamp(_quantiteMin, _quantiteMax).toInt()
        : 0;
    _definirQuantite(valeur);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int prixPub = widget.prixPublic > 0
        ? widget.prixPublic
        : (widget.prixGroupe > 0 ? (widget.prixGroupe * 1.45).round() : 0);
    final economie = prixPub > widget.prixGroupe ? prixPub - widget.prixGroupe : 0;
    final pourcentageEconomie = prixPub > 0 ? ((economie / prixPub) * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // AppBar avec image produit grand format
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                backgroundColor: AppTheme.couleurCarte(context),
                foregroundColor: AppTheme.couleurTexte(context),
                leadingWidth: 72,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 6, bottom: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.couleurCarte(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.couleurBordureForte(context), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context), size: 22),
                      tooltip: "Retour aux opportunités",
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: FavorisService.instance.favorisNotifier,
                  builder: (context, favoris, _) {
                    final isFav = favoris.contains(widget.id);
                    return CircleAvatar(
                      backgroundColor: AppTheme.couleurCarte(context),
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? AppTheme.couleurDanger(context) : AppTheme.couleurTexte(context),
                          size: 20,
                        ),
                        onPressed: () {
                          final model = GroupeCampagneModel(
                            id: widget.id,
                            titre: widget.titre,
                            sousTitre: widget.sousTitre,
                            imagePath: widget.imagePath,
                            prixGroupe: widget.prixGroupe,
                            prixPublic: widget.prixPublic,
                            quantiteActuelle: widget.quantiteActuelle,
                            quantiteObjectif: widget.quantiteObjectif,
                            categorie: widget.categorie,
                            paysOrigine: widget.paysOrigine,
                            courtierNom: widget.courtierNom,
                            tempsRestant: widget.tempsRestant,
                          );
                          FavorisService.instance.toggleFavori(model, context);
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: AppTheme.couleurCarte(context),
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Lien du groupe partagé dans le presse-papiers !"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppTheme.couleurSurfaceDouce(context),
                    child: Center(
                      child: imageProduit(
                        widget.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.shopping_bag_outlined,
                          size: 100,
                          color: AppTheme.couleurAccent(context),
                        ),
                      ),
                    ),
                  ),
                  // Badge Promo économie
                  Positioned(
                    bottom: 16,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 8),
                        ],
                      ),
                      child: Text(
                        "-$pourcentageEconomie% EN ACHAT GROUPÉ",
                        style: const TextStyle(
                          color: AppTheme.terre,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Badge temps restant
                  Positioned(
                    bottom: 16,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.tempsRestant,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenu de la fiche
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et sous-titre
                  Text(
                    widget.titre,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.couleurTexte(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.sousTitre,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.couleurTexteAttenue(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prix comparatifs (Wrap réactif sans aucun débordement de pixels)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "${widget.prixGroupe} FCFA",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.couleurAccent(context),
                            ),
                          ),
                          if (prixPub > widget.prixGroupe) ...[
                            const SizedBox(width: 8),
                            Text(
                              "$prixPub FCFA",
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.couleurTexteAttenue(context),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (economie > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.estSombre(context) ? AppTheme.darkOliveSurface : AppTheme.oliveClair,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Économie : ${economie * _quantite} FCFA",
                            style: TextStyle(
                              color: AppTheme.couleurSucces(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Bannière informative si le commerçant participe déjà à ce groupe
                  if (_quantiteDejaCommandee > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.ocre.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.ocre.withValues(alpha: 0.6), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppTheme.ocreProfond, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Vous participez déjà à ce groupe avec $_quantiteDejaCommandee pièce${_quantiteDejaCommandee > 1 ? 's' : ''}. Vous pouvez ajouter une commande supplémentaire.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.couleurTexte(context),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // JAUGE D'AVANCEMENT DU GROUPE D'ACHAT
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.couleurCarte(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.couleurAccent(context).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Progression du groupe ($_quantiteActuelle/$_quantiteObjectif lots)",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.couleurTexte(context),
                              ),
                            ),
                            Text(
                              "${(_pourcentage * 100).toInt()}%",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.couleurAccent(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _pourcentage,
                            minHeight: 10,
                            backgroundColor: AppTheme.couleurBordure(context),
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.couleurSucces(context)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: AppTheme.couleurAttention(context)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _quantiteRestante > 0
                                    ? "Plus que $_quantiteRestante commandes pour valider le tarif et déclencher le convoi !"
                                    : "Objectif atteint ! Expédition garantie.",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.couleurTexte(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SÉLECTEUR DE VARIANTES DU GROSSISTE (RG-12)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Variantes du grossiste :",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context)),
                      ),
                      if (_variantes.isNotEmpty)
                        Text(
                          "${_variantes.length} référence${_variantes.length > 1 ? 's' : ''}",
                          style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_variantes.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _variantes.map((v) {
                        final isSelected = _varianteSelectionnee?.id == v.id;
                        return InkWell(
                          onTap: () => setState(() => _varianteSelectionnee = v),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.couleurAccent(context) : AppTheme.couleurCarte(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.couleurAccent(context) : AppTheme.couleurBordureForte(context),
                                width: isSelected ? 2 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: isSelected ? AppTheme.texteSur(AppTheme.couleurAccent(context)) : AppTheme.couleurTexteAttenue(context),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  v.libelleComplet,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isSelected ? AppTheme.texteSur(AppTheme.couleurAccent(context)) : AppTheme.couleurTexte(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.couleurCarte(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.couleurBordure(context)),
                      ),
                    child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 18, color: AppTheme.couleurAccent(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Lot standard conforme au catalogue du grossiste",
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.couleurTexte(context)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // SÉLECTEUR DE QUANTITÉ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Quantité à réserver :",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context)),
                            ),
                            Text(
                              "Min: $_quantiteMin · Max: $_quantiteMax lot${_quantiteMax > 1 ? 's' : ''}",
                              style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.couleurCarte(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.couleurBordureForte(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _quantite > _quantiteMin
                                  ? () => _definirQuantite(_quantite - 1)
                                  : null,
                            ),
                            SizedBox(
                              width: 52,
                              child: TextField(
                                controller: _quantiteController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  TextInputFormatter.withFunction((ancien, nouveau) {
                                    final valeur = int.tryParse(nouveau.text);
                                    if (nouveau.text.isEmpty || valeur == null || valeur <= _quantiteMax) {
                                      return nouveau;
                                    }
                                    final plafond = '$_quantiteMax';
                                    return TextEditingValue(
                                      text: plafond,
                                      selection: TextSelection.collapsed(offset: plafond.length),
                                    );
                                  }),
                                ],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                ),
                                onChanged: (texte) {
                                  setState(() => _quantite = int.tryParse(texte) ?? 0);
                                },
                                onSubmitted: (_) => _terminerSaisieQuantite(),
                                onEditingComplete: _terminerSaisieQuantite,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: _quantite < _quantiteMax
                                  ? () => _definirQuantite(_quantite + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // INFOS LOGISTIQUES ET SÉCURITÉ
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.couleurCarte(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        if (widget.groupe?.grossisteNom.isNotEmpty ?? false) ...[
                          _buildInfoLigne(
                            icon: Icons.storefront_rounded,
                            titre: "Fournisseur certifié",
                            valeurWidget: Row(
                              children: [
                                if (widget.groupe?.grossistePhotoUrl != null && widget.groupe!.grossistePhotoUrl!.isNotEmpty) ...[
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundImage: imageReseauDimensionnee(context, widget.groupe!.grossistePhotoUrl!, 24),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    widget.groupe!.grossisteNom,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 20, color: AppTheme.couleurBordure(context)),
                        ],
                        _buildInfoLigne(
                          icon: Icons.flight_takeoff,
                          titre: "Provenance & Fret",
                          valeurWidget: DrapeauBadge(pays: widget.paysOrigine, compact: true),
                        ),
                        Divider(height: 20, color: AppTheme.couleurBordure(context)),
                        _buildInfoLigne(
                          icon: Icons.local_shipping_outlined,
                          titre: "Acheminement assuré par",
                          valeurWidget: Row(
                            children: [
                              if (widget.groupe?.courtierPhotoUrl != null && widget.groupe!.courtierPhotoUrl!.isNotEmpty) ...[
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: imageReseauDimensionnee(context, widget.groupe!.courtierPhotoUrl!, 24),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  widget.courtierNom.isNotEmpty ? widget.courtierNom : (widget.groupe?.grossisteNom ?? 'Karavan Transit'),
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.couleurTexte(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 20, color: AppTheme.couleurBordure(context)),
                        _buildInfoLigne(
                          icon: Icons.verified_user_outlined,
                          titre: "Garantie Karavan",
                          valeur: "Fonds protégés sous séquestre jusqu'au retrait",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Espace pour barre d'action fixe
                ],
              ),
            ),
          ),
        ],
      ),

      // Bouton flottant de retour en haut à gauche (Toujours visible et accessible)
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 14,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.couleurCarte(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.couleurBordureForte(context), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context), size: 20),
                  const SizedBox(width: 6),
                  Text(
                    "Retour",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppTheme.couleurTexte(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),

      // Barre d'action fixe en bas protégée des encoches et de la barre de navigation native (||| O <)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.estSombre(context) ? AppTheme.darkCard : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          minimum: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _quantiteMax < _quantiteMin ? "Statut du groupe :" : "Total à payer :",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _quantiteMax < _quantiteMin ? "100% Atteint" : "${widget.prixGroupe * _quantite} FCFA",
                          style: TextStyle(
                            fontSize: _quantiteMax < _quantiteMin ? 17 : 20,
                            fontWeight: FontWeight.w800,
                            color: _quantiteMax < _quantiteMin ? AppTheme.couleurSucces(context) : AppTheme.couleurAccent(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _quantite >= _quantiteMin && _quantite <= _quantiteMax ? () {
                      final gid = widget.id.isNotEmpty ? widget.id : widget.groupe?.id;
                      if (gid == null || gid.toString().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Groupe d'achat introuvable : rechargez la page.")),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RejoindreGroupeScreen(
                            groupeId: gid,
                            varianteId: _varianteSelectionnee?.id,
                            variante: _varianteSelectionnee,
                            variantesDisponibles: _variantes,
                            titre: widget.titre,
                            quantite: _quantite,
                            quantiteMin: _quantiteMin,
                            taille: _varianteSelectionnee?.libelleComplet ?? "",
                            prixUnitaire: widget.prixGroupe,
                            courtierNom: widget.courtierNom,
                            imagePath: widget.imagePath,
                            paysOrigine: widget.paysOrigine,
                            quantiteActuelle: _quantiteActuelle,
                            quantiteObjectif: _quantiteObjectif,
                            quantiteRestante: _quantiteRestante,
                          ),
                        ),
                      );
                    } : (_quantiteMax < _quantiteMin ? () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                      TabNavigationScope.switchToTab(context, 2);
                    } : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _quantiteMax < _quantiteMin
                          ? AppTheme.couleurSucces(context)
                          : AppTheme.couleurAccent(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _quantiteMax < _quantiteMin
                          ? "Groupe complet · Mes commandes →"
                          : "Rejoindre le groupe",
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
  );
}

  Widget _buildInfoLigne({
    required IconData icon,
    required String titre,
    String? valeur,
    Widget? valeurWidget,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.estSombre(context) ? AppTheme.darkPrimaryContainer : AppTheme.roseClair,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.couleurAccent(context)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
              ),
              const SizedBox(height: 2),
              if (valeurWidget != null)
                valeurWidget
              else
                Text(
                  valeur ?? '—',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.couleurTexte(context)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
