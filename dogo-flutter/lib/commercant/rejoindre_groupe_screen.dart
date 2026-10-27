import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../services/paiement_api_service.dart';
import '../services/groupe_api_service.dart';
import '../services/profil_api_service.dart';
import '../services/portefeuille_api_service.dart';
import '../services/auth_service.dart';
import '../services/api/api_client.dart';
import '../services/api/api_config.dart';
import '../services/api/api_exception.dart';
import 'campagne_model.dart';
import 'reussite_paiement_screen.dart';
import '../widgets/mobile_money_logo.dart';
import '../widgets/app_popups.dart';

/// Écran de confirmation de participation, choix des variantes/quantités et paiement Mobile Money pour le Commerçant
class RejoindreGroupeScreen extends StatefulWidget {
  /// Groupe rejoint : obligatoire, aucun groupe « par défaut » ne doit être débité par erreur.
  final dynamic groupeId;
  final int? varianteId;
  final VarianteGroupeModel? variante;
  final List<VarianteGroupeModel> variantesDisponibles;
  final String titre;
  final int quantite;
  final int quantiteMin;
  final String taille;
  final int prixUnitaire;
  final String courtierNom;
  final String imagePath;
  final String paysOrigine;
  final int quantiteActuelle;
  final int quantiteObjectif;
  final int? quantiteRestante;

  const RejoindreGroupeScreen({
    super.key,
    required this.groupeId,
    this.varianteId,
    this.variante,
    this.variantesDisponibles = const [],
    this.titre = "",
    this.quantite = 1,
    this.quantiteMin = 1,
    this.taille = "",
    this.prixUnitaire = 0,
    this.courtierNom = "",
    this.imagePath = "",
    this.paysOrigine = "",
    this.quantiteActuelle = 0,
    this.quantiteObjectif = 0,
    this.quantiteRestante,
  });

  @override
  State<RejoindreGroupeScreen> createState() => _RejoindreGroupeScreenState();
}

class _RejoindreGroupeScreenState extends State<RejoindreGroupeScreen> {
  String _operateurSelectionne = "Portefeuille Achats";
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _quantiteController = TextEditingController();
  bool _enCoursDeTraitement = false;
  String? _erreurTelephone;
  int _soldePortefeuille = 0;
  bool _portefeuilleCharge = false;

  late int _quantite;
  late int _quantiteMin;
  late int _quantiteObjectif;
  late int _quantiteRestante;
  List<VarianteGroupeModel> _variantes = [];
  VarianteGroupeModel? _varianteSelectionnee;

  final List<Map<String, dynamic>> _operateurs = [
    {
      "nom": "Portefeuille Achats",
      "couleur": AppTheme.oliveProfond,
      "sigle": "💼",
      "delai": "Instantané • Direct",
      "isPortefeuille": true,
    },
    {
      "nom": "Orange Money",
      "couleur": const Color(0xFFFF7900),
      "sigle": "OM",
      "delai": "Instantané",
      "isPortefeuille": false,
    },
    {
      "nom": "Moov Money",
      "couleur": const Color(0xFF005DAA),
      "sigle": "MM",
      "delai": "Instantané",
      "isPortefeuille": false,
    },
    {
      "nom": "Wave",
      "couleur": const Color(0xFF1DC7EA),
      "sigle": "W",
      "delai": "Sans frais",
      "isPortefeuille": false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _quantiteMin = widget.quantiteMin > 0 ? widget.quantiteMin : 1;
    _quantiteObjectif = widget.quantiteObjectif;
    _quantiteRestante = widget.quantiteRestante ??
        (_quantiteObjectif - widget.quantiteActuelle).clamp(0, _quantiteObjectif).toInt();
    _quantite = widget.quantite >= _quantiteMin ? widget.quantite : _quantiteMin;
    if (_quantiteMax >= _quantiteMin) {
      _quantite = _quantite.clamp(_quantiteMin, _quantiteMax).toInt();
    } else {
      _quantite = 0;
    }
    _quantiteController.text = '$_quantite';
    _variantes = List.from(widget.variantesDisponibles);
    _varianteSelectionnee = widget.variante;

    // Pré-remplir le numéro de téléphone avec celui de l'utilisateur connecté
    final telUser = AuthService.instance.profilActuel?.telephone;
    if (telUser != null && telUser.isNotEmpty) {
      _telephoneController.text = telUser;
    }

    if (_varianteSelectionnee == null && _variantes.isNotEmpty) {
      if (widget.varianteId != null) {
        _varianteSelectionnee = _variantes.firstWhere(
          (v) => v.id == widget.varianteId,
          orElse: () => _variantes.first,
        );
      } else {
        _varianteSelectionnee = _variantes.first;
      }
    }

    _chargerDetailsGroupe();
    _chargerMoyenPaiementDefaut();
    _chargerSoldePortefeuille();
  }

  Future<void> _chargerSoldePortefeuille() async {
    try {
      final p = await PortefeuilleApiService.instance.voirPortefeuille();
      if (p != null && mounted) {
        setState(() {
          _soldePortefeuille = p.soldeDisponible.toInt();
          _portefeuilleCharge = true;
          // Si le solde est insuffisant pour la commande actuelle, basculer vers Orange Money par défaut
          if (_soldePortefeuille < _total) {
            _operateurSelectionne = "Orange Money";
          }
        });
      }
    } catch (e) {
      debugPrint("Chargement portefeuille indisponible : $e");
    }
  }

  Future<void> _chargerMoyenPaiementDefaut() async {
    try {
      final moyens = await ProfilApiService.instance.mesMoyensPaiement();
      if (moyens.isNotEmpty && mounted) {
        final defaut = moyens.firstWhere((m) => m.parDefaut, orElse: () => moyens.first);
        setState(() {
          _telephoneController.text = defaut.numero;
          if (defaut.operateur == 'ORANGE_MONEY') {
            _operateurSelectionne = "Orange Money";
          } else if (defaut.operateur == 'MOOV_MONEY') {
            _operateurSelectionne = "Moov Money";
          } else if (defaut.operateur == 'WAVE') {
            _operateurSelectionne = "Wave";
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _chargerDetailsGroupe() async {
    try {
      final detail = await GroupeApiService.instance.detail(widget.groupeId);
      if (!mounted) return;
      setState(() {
        if (detail.variantes.isNotEmpty) _variantes = detail.variantes;
        if (detail.quantiteMinParCommercant > 0) {
          _quantiteMin = detail.quantiteMinParCommercant;
        }
        _quantiteObjectif = detail.quantiteObjectif;
        _quantiteRestante = detail.quantiteRestante;
        _quantite = _quantiteMax >= _quantiteMin
            ? _quantite.clamp(_quantiteMin, _quantiteMax).toInt()
            : 0;
        _quantiteController.text = '$_quantite';
        if (_variantes.isNotEmpty && _varianteSelectionnee == null) {
          if (widget.varianteId != null) {
            _varianteSelectionnee = _variantes.firstWhere(
              (v) => v.id == widget.varianteId,
              orElse: () => _variantes.first,
            );
          } else {
            _varianteSelectionnee = _variantes.first;
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _telephoneController.dispose();
    _quantiteController.dispose();
    super.dispose();
  }

  String _formatMontant(int montant) {
    final str = montant.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return "${str.replaceAllMapped(reg, (Match m) => '${m[1]} ')} FCFA";
  }

  int get _sousTotal => widget.prixUnitaire * _quantite;

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

  /// Montant réellement débité par le backend : prix figé × quantité (RG-29, RG-33).
  /// Le fret et le dédouanement sont déjà compris dans le prix groupé.
  int get _total => _sousTotal;

  String get _descriptionVariante {
    if (_varianteSelectionnee != null) {
      return " (${_varianteSelectionnee!.libelleComplet})";
    }
    if (widget.taille.trim().isNotEmpty) {
      return " (${widget.taille.trim()})";
    }
    return "";
  }

  void _validerPaiement() async {
    if (_quantite < _quantiteMin || _quantite > _quantiteMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("La quantité doit être comprise entre $_quantiteMin et $_quantiteMax lots.")),
      );
      return;
    }

    final bool estPortefeuille = _operateurSelectionne == "Portefeuille Achats";
    String digits = "";

    if (estPortefeuille) {
      if (_soldePortefeuille < _total) {
        AppPopups.afficherActionImpossible(
          context: context,
          titre: "Solde portefeuille insuffisant",
          message:
              "Votre solde disponible (${_formatMontant(_soldePortefeuille)}) est inférieur au montant requis (${_formatMontant(_total)}).",
          detail: "Veuillez recharger votre portefeuille d'achats ou choisir un paiement direct Mobile Money.",
        );
        return;
      }
    } else {
      final phone = _telephoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');
      digits = phone.replaceAll(RegExp(r'^\+223|^00223'), '');

      if (digits.length != 8 || !RegExp(r'^[5-9][0-9]{7}$').hasMatch(digits)) {
        setState(() {
          _erreurTelephone = "Numéro Mobile Money invalide (8 chiffres, ex: 76 45 88 12)";
        });
        return;
      }
    }

    final vId = _varianteSelectionnee?.id ?? widget.varianteId;
    if (vId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner une variante de produit."),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() {
      _erreurTelephone = null;
      _enCoursDeTraitement = true;
    });

    try {
      // Étape 1 : Réservation / Participation au groupe côté backend (RG-26 à RG-29)
      Map<String, dynamic> participation;
      try {
        participation = await GroupeApiService.instance.rejoindreGroupe(
          groupeId: widget.groupeId,
          varianteId: vId,
          quantite: _quantite,
        );
      } on ApiException catch (err) {
        // RG-26 : une participation active existe déjà pour cette variante → c'est elle qu'on règle
        if (err.statusCode != 409) rethrow;
        final existante = await _participationActiveExistante();
        if (existante == null) rethrow;
        participation = existante;
      }
      final participationId = (participation['id'] as num).toInt();

      // Étape 2 : Paiement de la participation (RG-33, RG-34)
      if (estPortefeuille) {
        await PaiementApiService.instance.initierPaiement(
          participationId: participationId,
          utiliserPortefeuille: true,
        );
      } else {
        // Le moyen débité est exactement le numéro saisi (RG-10), jamais un autre moyen enregistré
        final moyenPaiementId = await _moyenPaiementPour(digits);
        await PaiementApiService.instance.initierPaiement(
          participationId: participationId,
          moyenPaiementId: moyenPaiementId,
          utiliserPortefeuille: false,
        );
      }

      // Le reçu reprend ce que le serveur a réellement réservé et débité
      final quantiteReservee = (participation['quantite'] as num?)?.toInt() ?? _quantite;
      final prixFige = (participation['prixUnitaire'] as num?)?.round() ?? widget.prixUnitaire;
      final montantDebite = (participation['montant'] as num?)?.round() ?? _total;

      // Progression réelle du groupe après ce paiement
      int piecesActuelles = widget.quantiteActuelle;
      int piecesObjectif = widget.quantiteObjectif;
      try {
        final groupe = await GroupeApiService.instance.detail(widget.groupeId);
        piecesActuelles = groupe.quantiteActuelle;
        piecesObjectif = groupe.quantiteObjectif;
      } catch (_) {}

      // Si le backend n'a pas encore actualisé la somme ou en cas de synchronisation,
      // la jauge intègre au minimum la commande qui vient d'être payée
      if (piecesObjectif > 0 && piecesActuelles < (widget.quantiteActuelle + quantiteReservee)) {
        piecesActuelles = (widget.quantiteActuelle + quantiteReservee).clamp(0, piecesObjectif);
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ReussitePaiementScreen(
            groupeId: widget.groupeId,
            participationId: participationId,
            titreProduit: widget.titre,
            paysOrigine: widget.paysOrigine,
            prixUnitaire: prixFige,
            quantite: quantiteReservee,
            montantTotal: montantDebite,
            moyenPaiement: _operateurSelectionne,
            dateHeure: "Aujourd'hui - ${TimeOfDay.now().format(context)}",
            imagePath: widget.imagePath,
            piecesActuelles: piecesActuelles,
            piecesObjectif: piecesObjectif,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      await AppPopups.traiterErreurOuConflit(
        context,
        e,
        onAllerAuxCommandes: () {
          Navigator.of(context).pop();
        },
      );
    } finally {
      if (mounted) setState(() => _enCoursDeTraitement = false);
    }
  }

  /// Participation encore à payer pour ce groupe et cette variante (le 409 RG-26 porte sur la variante).
  Future<Map<String, dynamic>?> _participationActiveExistante() async {
    final sku = _varianteSelectionnee?.sku;
    final mesParticipations = await ApiClient.instance.get(ApiConfig.mesParticipations);
    if (mesParticipations is! List) return null;
    for (final p in mesParticipations.whereType<Map<String, dynamic>>()) {
      final memeGroupe = p['groupeId'].toString() == widget.groupeId.toString();
      final memeVariante = sku == null || sku.isEmpty || p['sku'] == sku;
      final aPayer = p['statut'] == 'RESERVEE' || p['statut'] == 'DEMANDEE';
      if (memeGroupe && memeVariante && aPayer && p['id'] is num) return p;
    }
    return null;
  }

  /// Identifiant du moyen Mobile Money correspondant au numéro saisi, enregistré au besoin.
  Future<int> _moyenPaiementPour(String digits) async {
    final moyens = await ProfilApiService.instance.mesMoyensPaiement();
    for (final m in moyens) {
      if (m.numero.replaceAll(RegExp(r'[\s\-]'), '').endsWith(digits)) return m.id;
    }
    final codeOperateur = switch (_operateurSelectionne.toLowerCase()) {
      final s when s.contains('moov') => 'MOOV_MONEY',
      final s when s.contains('wave') => 'WAVE',
      _ => 'ORANGE_MONEY',
    };
    final nouveau = await ProfilApiService.instance.ajouterMoyenPaiement(
      numero: "+223$digits",
      operateur: codeOperateur,
      parDefaut: true,
    );
    return nouveau.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        title: const Text(
          "Paiement & Réservation",
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.couleurCarte(context),
        elevation: 0,
        foregroundColor: AppTheme.couleurTexte(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SÉLECTION DES VARIANTES FOURNIES PAR LE GROSSISTE
            if (_variantes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.couleurCarte(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A2C241E), blurRadius: 15, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "Variantes du Grossiste :",
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.couleurAccent(context).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${_variantes.length} réf.",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.couleurAccent(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _variantes.map((v) {
                        final isSelected = _varianteSelectionnee?.id == v.id;
                        return InkWell(
                          onTap: () => setState(() => _varianteSelectionnee = v),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.couleurAccent(context) : AppTheme.couleurCarte(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.couleurAccent(context) : AppTheme.couleurBordureForte(context),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.couleurAccent(context).withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
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
                                Flexible(
                                  child: Text(
                                    v.libelleComplet,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isSelected ? AppTheme.texteSur(AppTheme.couleurAccent(context)) : AppTheme.couleurTexte(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // 2. RÉCAPITULATIF COMMANDE & CHOIX QUANTITÉ
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.couleurCarte(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A2C241E), blurRadius: 15, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Récapitulatif de la réservation",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "${widget.titre}$_descriptionVariante",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Text(
                        _formatMontant(widget.prixUnitaire),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.couleurAccent(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sélecteur de quantité interactif
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.couleurSurfaceDouce(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.couleurBordure(context)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isCompact = constraints.maxWidth < 280;
                        final stepper = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: Icon(Icons.remove_circle_outline, color: AppTheme.couleurAccent(context)),
                              iconSize: 24,
                              onPressed: _quantite > _quantiteMin
                                  ? () => _definirQuantite(_quantite - 1)
                                  : null,
                            ),
                            SizedBox(
                              width: 54,
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
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: Icon(Icons.add_circle, color: AppTheme.couleurAccent(context)),
                              iconSize: 24,
                              onPressed: _quantite < _quantiteMax
                                  ? () => _definirQuantite(_quantite + 1)
                                  : null,
                            ),
                          ],
                        );

                        final labelColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Quantité réservée :",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.couleurTexte(context)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Min. $_quantiteMin · Max. $_quantiteMax lot${_quantiteMax > 1 ? 's' : ''}",
                              style: TextStyle(fontSize: 11, color: AppTheme.couleurTexteAttenue(context)),
                            ),
                          ],
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              labelColumn,
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: stepper,
                              ),
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: labelColumn),
                            const SizedBox(width: 8),
                            stepper,
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),
                  Divider(color: AppTheme.couleurBordure(context)),
                  const SizedBox(height: 8),
                  _buildLigneMontant(
                    "Sous-total marchandise ($_quantite x ${_formatMontant(widget.prixUnitaire)})",
                    _formatMontant(_sousTotal),
                  ),
                  const SizedBox(height: 6),
                  _buildLigneMontant("Fret & dédouanement", "Inclus dans le prix", isGratuit: true),
                  const SizedBox(height: 6),
                  _buildLigneMontant("Garantie Séquestre Karavan", "0 FCFA (Inclus)", isGratuit: true),
                  const SizedBox(height: 12),
                  Divider(color: AppTheme.couleurBordure(context)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Total à payer :",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatMontant(_total),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.couleurAccent(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mode de paiement
            Text(
              "Choisir votre moyen de paiement :",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context)),
            ),
            const SizedBox(height: 12),

            ..._operateurs.map((op) {
              final isSelected = op["nom"] == _operateurSelectionne;
              final isPortefeuille = op["isPortefeuille"] == true;
              return GestureDetector(
                onTap: () => setState(() => _operateurSelectionne = op["nom"]),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.couleurCarte(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.couleurAccent(context) : AppTheme.couleurBordureForte(context),
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isPortefeuille)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: op["couleur"] as Color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              "💼",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        )
                      else
                        MobileMoneyLogo(
                          operateur: op["nom"] as String,
                          taille: 40,
                          estCercle: false,
                          rayonArrondi: 10,
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  op["nom"] as String,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context)),
                                ),
                                if (isPortefeuille && _portefeuilleCharge)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.couleurFondSucces(context),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _formatMontant(_soldePortefeuille),
                                      style: TextStyle(
                                        color: AppTheme.couleurSucces(context),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              isPortefeuille
                                  ? (_soldePortefeuille >= _total
                                      ? "Solde suffisant • Débit immédiat"
                                      : "Solde insuffisant (manque ${_formatMontant(_total - _soldePortefeuille)})")
                                  : (op["delai"] as String),
                              style: TextStyle(
                                color: isPortefeuille && _soldePortefeuille < _total
                                    ? AppTheme.danger
                                    : AppTheme.couleurTexteAttenue(context),
                                fontSize: 12,
                                fontWeight: isPortefeuille && _soldePortefeuille < _total
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.couleurAccent(context) : AppTheme.couleurTexteAttenue(context),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Saisie du numéro de téléphone OU Informations portefeuille
            if (_operateurSelectionne == "Portefeuille Achats") ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _soldePortefeuille >= _total
                      ? AppTheme.couleurFondSucces(context)
                      : AppTheme.couleurFondDanger(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _soldePortefeuille >= _total
                        ? AppTheme.oliveBordure
                        : AppTheme.dangerBordure,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _soldePortefeuille >= _total
                          ? Icons.account_balance_wallet
                          : Icons.warning_amber_rounded,
                      color: _soldePortefeuille >= _total
                          ? AppTheme.couleurSucces(context)
                          : AppTheme.couleurAttention(context),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _soldePortefeuille >= _total
                                ? "Règlement direct par portefeuille"
                                : "Solde insuffisant pour cet achat",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _soldePortefeuille >= _total
                                  ? AppTheme.couleurSucces(context)
                                  : AppTheme.couleurAttention(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _soldePortefeuille >= _total
                                ? "Le montant de ${_formatMontant(_total)} sera prélevé de votre solde (${_formatMontant(_soldePortefeuille)}). Vous conserverez ${_formatMontant(_soldePortefeuille - _total)}."
                                : "Votre solde est de ${_formatMontant(_soldePortefeuille)}. Veuillez recharger votre portefeuille ou opter pour un paiement Mobile Money.",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _soldePortefeuille >= _total
                                  ? AppTheme.couleurSucces(context)
                                  : AppTheme.couleurAttention(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                "Numéro de téléphone de facturation :",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.couleurTexte(context)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                onChanged: (_) {
                  if (_erreurTelephone != null) {
                    setState(() => _erreurTelephone = null);
                  }
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.couleurCarte(context),
                  prefixIcon: Icon(Icons.phone_iphone, color: AppTheme.couleurAccent(context)),
                  errorText: _erreurTelephone,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppTheme.couleurBordureForte(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppTheme.couleurBordureForte(context)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Notice Séquestre DoGo
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, color: AppTheme.couleurAttention(context), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Paiement protégé sous séquestre jusqu'à l'arrivée du convoi.",
                      style: TextStyle(fontSize: 11.5, color: AppTheme.couleurAttention(context), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Bouton de validation
            ElevatedButton(
              onPressed: _enCoursDeTraitement ||
                      _quantite < _quantiteMin ||
                      _quantite > _quantiteMax
                  ? null
                  : _validerPaiement,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.couleurAccent(context),
                foregroundColor: AppTheme.texteSur(AppTheme.couleurAccent(context)),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _enCoursDeTraitement
              ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.texteSur(AppTheme.couleurAccent(context))),
                      ),
                    )
                  : Text(
                      "Payer ${_formatMontant(_total)}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLigneMontant(String libelle, String montant, {bool isGratuit = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(libelle, style: TextStyle(fontSize: 12.5, color: AppTheme.couleurTexteAttenue(context))),
        ),
        Text(
          montant,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isGratuit ? AppTheme.couleurSucces(context) : AppTheme.couleurTexte(context),
          ),
        ),
      ],
    );
  }
}
