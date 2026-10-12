import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/role_acteur.dart';
import '../services/auth_service.dart';
import '../services/api/api_exception.dart';
import 'commercant_otp_screen.dart';

/// Écran d'Inscription conforme au modèle Figma exact et aux specs backend (mot de passe + infos métier)
class CommercantInscriptionScreen extends StatefulWidget {
  final RoleActeur role;

  const CommercantInscriptionScreen({
    super.key,
    this.role = RoleActeur.commercant,
  });

  @override
  State<CommercantInscriptionScreen> createState() => _CommercantInscriptionScreenState();
}

class _CommercantInscriptionScreenState extends State<CommercantInscriptionScreen> {
  final _nomController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _extraField1Controller = TextEditingController();
  final _extraField2Controller = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _extraField1Controller.dispose();
    _extraField2Controller.dispose();
    super.dispose();
  }

  void _validerInscription() async {
    final nom = _nomController.text.trim();
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez renseigner votre nom complet ou raison sociale")),
      );
      return;
    }

    if (phone.isEmpty || phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez renseigner un numéro de téléphone valide")),
      );
      return;
    }

    if (pin.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le mot de passe doit comporter au moins 8 caractères")),
      );
      return;
    }

    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les deux mots de passe saisis ne correspondent pas")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.instance.inscrire(
        typeActeur: widget.role.name.toUpperCase(),
        telephone: phone,
        nom: nom,
        motDePasse: pin,
        pin: pin,
        nomBoutique: widget.role == RoleActeur.commercant ? _extraField1Controller.text.trim() : null,
        quartierBamako: widget.role == RoleActeur.commercant ? _extraField2Controller.text.trim() : null,
        numeroNif: widget.role == RoleActeur.grossiste ? _extraField1Controller.text.trim() : null,
        nomBoutiqueMarche: widget.role == RoleActeur.grossiste ? _extraField2Controller.text.trim() : null,
        nomSocieteImport: widget.role == RoleActeur.courtier
            ? (_extraField2Controller.text.trim().isNotEmpty ? _extraField2Controller.text.trim() : nom)
            : (widget.role == RoleActeur.grossiste ? _extraField2Controller.text.trim() : null),
        licenceTransit: widget.role == RoleActeur.courtier ? _extraField1Controller.text.trim() : null,
        adresseDepot: widget.role == RoleActeur.courtier ? _extraField2Controller.text.trim() : null,
      );

      if (!mounted) return;

      final codeSimule = res['codeOtp']?.toString();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommercantOtpScreen(
            numeroTelephone: phone,
            role: widget.role,
            codeSimulation: codeSimule,
            motDePasse: pin,
            pin: pin,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.messageComplet : 'Erreur d\'inscription : ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFC0392B),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const camelColor = Color(0xFFA67954);
    const borderColor = Color(0xFFDFCABA);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // Fond crème doux Design System
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: camelColor, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. TITRE PRINCIPAL FIGMA
              const Text(
                "Inscription",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1E24),
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 6),
              Text(
                "Compte ${widget.role.libelle}",
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: camelColor,
                ),
              ),

              const SizedBox(height: 24),

              // 2. CHAMP NOM COMPLET
              _buildFigmaInputField(
                icon: Icons.person_outline,
                label: "Nom complet / Raison sociale",
                hint: "Ex: Fatoumata Diarra ou Diarra Trading",
                controller: _nomController,
                borderColor: borderColor,
                camelColor: camelColor,
              ),

              const SizedBox(height: 14),

              // 3. CHAMP TÉLÉPHONE
              _buildFigmaInputField(
                icon: Icons.phone_outlined,
                label: "Téléphone Mobile Money",
                hint: "Ex: +223 70 12 34 56",
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                borderColor: borderColor,
                camelColor: camelColor,
              ),

              const SizedBox(height: 14),

              // 4. CHAMP MOT DE PASSE (8 caractères minimum)
              _buildFigmaInputField(
                icon: Icons.lock_outline,
                label: "Mot de passe (8 caractères minimum)",
                hint: "•••••••• (Au moins 8 caractères)",
                controller: _pinController,
                obscureText: _obscurePin,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(64),
                ],
                borderColor: borderColor,
                camelColor: camelColor,
                trailing: IconButton(
                  icon: Icon(
                    _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: camelColor,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePin = !_obscurePin);
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 5. CHAMP CONFIRMATION DU MOT DE PASSE
              _buildFigmaInputField(
                icon: Icons.lock_outline,
                label: "Confirmer le mot de passe",
                hint: "•••••••• (Répéter le mot de passe)",
                controller: _confirmPinController,
                obscureText: _obscureConfirmPin,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(64),
                ],
                borderColor: borderColor,
                camelColor: camelColor,
                trailing: IconButton(
                  icon: Icon(
                    _obscureConfirmPin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: camelColor,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirmPin = !_obscureConfirmPin);
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 6. CHAMPS SPÉCIFIQUES AU RÔLE (Pour conformité Backend Dogo)
              if (widget.role == RoleActeur.commercant) ...[
                _buildFigmaInputField(
                  icon: Icons.storefront_outlined,
                  label: "Nom de la boutique",
                  hint: "Ex: Boutique Élégance Dabanani",
                  controller: _extraField1Controller,
                  borderColor: borderColor,
                  camelColor: camelColor,
                ),
                const SizedBox(height: 14),
                _buildFigmaInputField(
                  icon: Icons.place_outlined,
                  label: "Quartier / Marché Bamako",
                  hint: "Ex: Grand Marché Dabanani, Missira",
                  controller: _extraField2Controller,
                  borderColor: borderColor,
                  camelColor: camelColor,
                ),
              ] else if (widget.role == RoleActeur.grossiste) ...[
                _buildFigmaInputField(
                  icon: Icons.store_mall_directory_outlined,
                  label: "Nom de la boutique au marché",
                  hint: "Ex: Grand Dépôt Dabanani ou SoloImport",
                  controller: _extraField2Controller,
                  borderColor: borderColor,
                  camelColor: camelColor,
                ),
                const SizedBox(height: 14),
                _buildFigmaInputField(
                  icon: Icons.badge_outlined,
                  label: "Numéro NIF / Registre de Commerce",
                  hint: "Ex: 084192043M ou RCCM-BKO-2024",
                  controller: _extraField1Controller,
                  borderColor: borderColor,
                  camelColor: camelColor,
                ),
              ] else if (widget.role == RoleActeur.courtier) ...[
                _buildFigmaInputField(
                  icon: Icons.verified_user_outlined,
                  label: "Licence de transit / Agrément",
                  hint: "Ex: Agrément CEMAC/UEMOA 2026",
                  controller: _extraField1Controller,
                  borderColor: borderColor,
                  camelColor: camelColor,
                ),
                const SizedBox(height: 14),
                _buildFigmaInputField(
                  icon: Icons.warehouse_outlined,
                  label: "Adresse du dépôt / Hub Bamako",
                  hint: "Ex: Dabanani Porte 14 ou Halles de Bamako",
                  controller: _extraField2Controller,
                  borderColor: borderColor,
                  camelColor: camelColor,
                ),
              ],

              const SizedBox(height: 28),

              // 7. BOUTON PRINCIPAL "S'INSCRIRE"
              ElevatedButton(
                onPressed: _isLoading ? null : _validerInscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: camelColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                      )
                    : const Text(
                        "S'inscrire",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // 8. LIEN INFÉRIEUR "VOUS AVEZ DÉJÀ UN COMPTE ? SE CONNECTER"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Vous avez déjà un compte ? ",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      "Se connecter",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: camelColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Champ de saisie Figma avec bordure douce, cercle d'icône et double ligne (Label + Saisie)
  Widget _buildFigmaInputField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required Color borderColor,
    required Color camelColor,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0646321E),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cercle autour de l'icône
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.1),
            ),
            child: Icon(icon, color: camelColor, size: 19),
          ),
          const SizedBox(width: 14),

          // Label supérieur + Champ de texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A7768),
                  ),
                ),
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  obscureText: obscureText,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E24),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFA59A91),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),

          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
