import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/paiement_api_service.dart';
import '../services/groupe_api_service.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import 'campagne_model.dart';
import 'reussite_paiement_screen.dart';

/// Écran de confirmation de participation, choix des variantes/quantités et paiement Mobile Money pour le Commerçant
class RejoindreGroupeScreen extends StatefulWidget {
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

  const RejoindreGroupeScreen({
    super.key,
    this.groupeId = 1,
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
  });

  @override
  State<RejoindreGroupeScreen> createState() => _RejoindreGroupeScreenState();
}

class _RejoindreGroupeScreenState extends State<RejoindreGroupeScreen> {
  String _operateurSelectionne = "Orange Money";
  final TextEditingController _telephoneController =
      TextEditingController(text: "+223 76 45 88 12");
  bool _enCoursDeTraitement = false;
  String? _erreurTelephone;

  late int _quantite;
  late int _quantiteMin;
  List<VarianteGroupeModel> _variantes = [];
  VarianteGroupeModel? _varianteSelectionnee;

  final List<Map<String, dynamic>> _operateurs = [
    {
      "nom": "Orange Money",
      "couleur": const Color(0xFFFF7900),
      "sigle": "OM",
      "delai": "Instantané",
    },
    {
      "nom": "Moov Money",
      "couleur": const Color(0xFF005DAA),
      "sigle": "MM",
      "delai": "Instantané",
    },
    {
      "nom": "Wave",
      "couleur": const Color(0xFF1DC7EA),
      "sigle": "W",
      "delai": "Sans frais",
    },
  ];

  @override
  void initState() {
    super.initState();
    _quantiteMin = widget.quantiteMin > 0 ? widget.quantiteMin : 1;
    _quantite = widget.quantite >= _quantiteMin ? widget.quantite : _quantiteMin;
    _variantes = List.from(widget.variantesDisponibles);
    _varianteSelectionnee = widget.variante;

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

    _chargerVariantesSiBesoin();
  }

  Future<void> _chargerVariantesSiBesoin() async {
    if (_variantes.isNotEmpty) return;
    try {
      final detail = await GroupeApiService.instance.detail(widget.groupeId);
      if (!mounted) return;
      setState(() {
        _variantes = detail.variantes;
        if (detail.quantiteMinParCommercant > 0) {
          _quantiteMin = detail.quantiteMinParCommercant;
          if (_quantite < _quantiteMin) _quantite = _quantiteMin;
        }
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
    super.dispose();
  }

  String _formatMontant(int montant) {
    final str = montant.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return "${str.replaceAllMapped(reg, (Match m) => '${m[1]} ')} FCFA";
  }

  int get _sousTotal => widget.prixUnitaire * _quantite;

  int get _fraisTransport {
    // Quote-part fret et dédouanement calculée proportionnellement à la commande
    final base = (_sousTotal * 0.05).round();
    return base.clamp(1500, 15000);
  }

  int get _total => _sousTotal + _fraisTransport;

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
    final phone = _telephoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');
    final digits = phone.replaceAll(RegExp(r'^\+223|^00223'), '');

    if (digits.length != 8 || !RegExp(r'^[5-9][0-9]{7}$').hasMatch(digits)) {
      setState(() {
        _erreurTelephone = "Numéro Mobile Money invalide (8 chiffres, ex: 76 45 88 12)";
      });
      return;
    }

    final vId = _varianteSelectionnee?.id ?? widget.varianteId;
    if (vId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner une variante de produit."),
          backgroundColor: Color(0xFFC0392B),
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
      int? participationId;
      try {
        final reponse = await GroupeApiService.instance.rejoindreGroupe(
          groupeId: widget.groupeId,
          varianteId: vId,
          quantite: _quantite,
        );
        participationId = reponse['id'] is num
            ? (reponse['id'] as num).toInt()
            : int.tryParse(reponse['id']?.toString() ?? '');
      } catch (err) {
        // En cas de conflit (déjà réservé), réutiliser la participation active existante
        if (err is ApiException && err.statusCode == 409) {
          final mesPart = await ApiClient.instance.get('/api/moi/participations');
          if (mesPart is List) {
            final existante = mesPart.firstWhere(
              (p) =>
                  p['groupeId'].toString() == widget.groupeId.toString() &&
                  (p['statut'] == 'DEMANDEE' || p['statut'] == 'RESERVEE'),
              orElse: () => null,
            );
            if (existante != null && existante['id'] != null) {
              participationId = existante['id'] as int;
            }
          }
        }
        if (participationId == null) rethrow;
      }

      if (participationId == null) {
        throw Exception("Impossible d'initialiser la réservation de participation.");
      }

      // Étape 2 : Paiement Mobile Money avec l'ID réel de la participation (RG-34)
      await PaiementApiService.instance.initierPaiement(
        participationId: participationId,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReussitePaiementScreen(
            titreProduit: widget.titre,
            paysOrigine: widget.paysOrigine,
            prixUnitaire: widget.prixUnitaire,
            quantite: _quantite,
            montantTotal: _total,
            moyenPaiement: _operateurSelectionne,
            dateHeure: "Aujourd'hui - ${TimeOfDay.now().format(context)}",
            imagePath: widget.imagePath,
            piecesActuelles: 780,
            piecesObjectif: 1000,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.messageComplet : 'Erreur de paiement : ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFC0392B),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _enCoursDeTraitement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Paiement & Réservation",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A46321E), blurRadius: 15, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Variantes du Grossiste :",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${_variantes.length} réf.",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
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
                              color: isSelected ? AppTheme.primary : const Color(0xFFF9F7F5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : const Color(0xFFDED6CE),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.25),
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
                                  color: isSelected ? Colors.white : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  v.libelleComplet,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A46321E), blurRadius: 15, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Récapitulatif de la réservation",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sélecteur de quantité interactif
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7F5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEBE3D9)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quantité réservée :",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            Text(
                              "Minimum exigé : $_quantiteMin lot${_quantiteMin > 1 ? 's' : ''}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primary),
                              iconSize: 24,
                              onPressed: _quantite > _quantiteMin
                                  ? () => setState(() => _quantite--)
                                  : null,
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 36),
                              alignment: Alignment.center,
                              child: Text(
                                "$_quantite",
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                              iconSize: 24,
                              onPressed: () => setState(() => _quantite++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFF1EAE2)),
                  const SizedBox(height: 8),
                  _buildLigneMontant(
                    "Sous-total marchandise ($_quantite x ${_formatMontant(widget.prixUnitaire)})",
                    _formatMontant(_sousTotal),
                  ),
                  const SizedBox(height: 6),
                  _buildLigneMontant("Quote-part fret & dédouanement", _formatMontant(_fraisTransport)),
                  const SizedBox(height: 6),
                  _buildLigneMontant("Garantie Séquestre DoGo", "0 FCFA (Inclus)", isGratuit: true),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1EAE2)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total à payer :",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      Text(
                        _formatMontant(_total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mode de paiement Mobile Money
            const Text(
              "Choisir votre moyen de paiement Mobile Money :",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 12),

            ..._operateurs.map((op) {
              final isSelected = op["nom"] == _operateurSelectionne;
              return GestureDetector(
                onTap: () => setState(() => _operateurSelectionne = op["nom"]),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : const Color(0xFFE2D9D0),
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: op["couleur"] as Color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            op["sigle"] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              op["nom"] as String,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              op["delai"] as String,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.primary : const Color(0xFFC7BCB2),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Saisie du numéro de téléphone
            const Text(
              "Numéro de téléphone de facturation :",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.phone_iphone, color: AppTheme.primary),
                errorText: _erreurTelephone,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2D9D0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2D9D0)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Notice Séquestre DoGo
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, color: AppTheme.secondary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Paiement protégé sous séquestre jusqu'à l'arrivée du convoi.",
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF6B4E00), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Bouton de validation
            ElevatedButton(
              onPressed: _enCoursDeTraitement ? null : _validerPaiement,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _enCoursDeTraitement
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
          child: Text(libelle, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
        ),
        Text(
          montant,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isGratuit ? AppTheme.success : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
