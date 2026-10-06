import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/paiement_api_service.dart';
import '../services/api/api_exception.dart';
import 'reussite_paiement_screen.dart';

/// Écran de confirmation de participation et paiement Mobile Money pour le Commerçant
class RejoindreGroupeScreen extends StatefulWidget {
  final dynamic groupeId;
  final int? varianteId;
  final String titre;
  final int quantite;
  final String taille;
  final int prixUnitaire;
  final String courtierNom;

  const RejoindreGroupeScreen({
    super.key,
    this.groupeId = 1,
    this.varianteId = 1,
    this.titre = "Sneakers Nike Joyride (Export Turquie)",
    this.quantite = 5,
    this.taille = "42",
    this.prixUnitaire = 18500,
    this.courtierNom = "Touré Transit & Logistique SARL",
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
  void dispose() {
    _telephoneController.dispose();
    super.dispose();
  }

  String _formatMontant(int montant) {
    final str = montant.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return "${str.replaceAllMapped(reg, (Match m) => '${m[1]} ')} FCFA";
  }

  int get _sousTotal => widget.prixUnitaire * widget.quantite;

  int get _fraisTransport {
    // Quote-part fret et dédouanement calculée proportionnellement à la commande
    final base = (_sousTotal * 0.05).round();
    return base.clamp(1500, 15000);
  }

  int get _total => _sousTotal + _fraisTransport;

  String get _descriptionTaille {
    if (widget.taille.trim().isEmpty) return "";
    final isNum = int.tryParse(widget.taille) != null;
    if (isNum && int.parse(widget.taille) >= 35 && int.parse(widget.taille) <= 48) {
      return " (Pointure ${widget.taille})";
    } else if (['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'].contains(widget.taille.toUpperCase())) {
      return " (Taille ${widget.taille})";
    }
    return " (${widget.taille})";
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

    setState(() {
      _erreurTelephone = null;
      _enCoursDeTraitement = true;
    });

    try {
      // Appel API avec génération automatique de l'en-tête Idempotency-Key (RG-34)
      await PaiementApiService.instance.initierPaiement(
        participationId: widget.groupeId ?? 1,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReussitePaiementScreen(
            titreProduit: widget.titre,
            paysOrigine: "Turquie",
            prixUnitaire: widget.prixUnitaire,
            quantite: widget.quantite,
            montantTotal: _total,
            moyenPaiement: _operateurSelectionne,
            dateHeure: "Aujourd'hui - ${TimeOfDay.now().format(context)}",
            imagePath: "assets/images/Nike_Joyride-removebg-preview.png",
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
            // Récapitulatif commande
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
                          "${widget.titre}$_descriptionTaille",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Text(
                        "${widget.quantite} x ${_formatMontant(widget.prixUnitaire)}",
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFF1EAE2)),
                  const SizedBox(height: 8),
                  _buildLigneMontant("Sous-total marchandise", _formatMontant(_sousTotal)),
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
                      "Paiement protégé jusqu'à l'arrivée du convoi.",
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
        Text(libelle, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
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
