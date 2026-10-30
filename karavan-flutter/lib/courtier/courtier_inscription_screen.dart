import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../commercant/commercant_otp_screen.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/session_storage_service.dart';
import '../services/validateur_mot_de_passe.dart';
import '../theme/app_theme.dart';
import '../widgets/bouton_bascule_theme.dart';
import '../widgets/bouton_google_signin.dart';

/// Écran d'Inscription dédié exclusivement au Courtier (Transit, Groupage & Retraits).
/// Soumis aux critères de validation Courtier : pièce d'identité + licence de transitaire.
class CourtierInscriptionScreen extends StatefulWidget {
  final String? initialTelephone;

  const CourtierInscriptionScreen({
    super.key,
    this.initialTelephone,
  });

  @override
  State<CourtierInscriptionScreen> createState() =>
      _CourtierInscriptionScreenState();
}

class _CourtierInscriptionScreenState extends State<CourtierInscriptionScreen> {
  final _societeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    GoogleSignInService.instance.definirContexteEnCours(
      role: RoleActeur.courtier,
      estInscription: true,
    );
    SessionStorageService.instance.sauvegarderDernierEspace('courtier');
    if (widget.initialTelephone != null && widget.initialTelephone!.isNotEmpty) {
      _phoneController.text = widget.initialTelephone!;
    }
  }

  @override
  void dispose() {
    _societeController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _validerInscription() async {
    final societe = _societeController.text.trim();
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (societe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez renseigner le nom de votre société de transit ou votre nom complet"),
        ),
      );
      return;
    }

    if (phone.replaceAll(RegExp(r'\D'), '').length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez renseigner un numéro de téléphone valide")),
      );
      return;
    }

    final erreurMdp = ValidateurMotDePasse.validerCreation(pin);
    if (erreurMdp != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erreurMdp)),
      );
      return;
    }

    final erreurConf = ValidateurMotDePasse.validerConfirmation(pin, confirmPin);
    if (erreurConf != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erreurConf)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.inscrire(
        typeActeur: RoleActeur.courtier.codeBackend,
        telephone: phone,
        nom: societe,
        motDePasse: pin,
        pin: pin,
        nomSocieteImport: societe,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommercantOtpScreen(
            numeroTelephone: phone,
            role: RoleActeur.courtier,
            nom: societe,
            motDePasse: pin,
            pin: pin,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.messageComplet
          : "Erreur d'inscription : ${e.toString()}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const camelColor = AppTheme.bissap;
    final estSombre = AppTheme.estSombre(context);

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: camelColor, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: const [
          BoutonBasculeTheme(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_karavan.png',
                height: 58,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                "Inscription Courtier",
                style: TextStyle(
                  fontFamily: AppTheme.policeTitre,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexte(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: camelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_rounded, size: 15, color: camelColor),
                    SizedBox(width: 6),
                    Text(
                      "Compte Courtier • Transit & Groupage",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: camelColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _buildInputField(
                icon: Icons.local_shipping_outlined,
                label: "Société de transit / Commissionnaire",
                hint: "Ex: Sahel Transit Logistics",
                controller: _societeController,
                camelColor: camelColor,
              ),
              const SizedBox(height: 14),
              _buildInputField(
                icon: Icons.phone_outlined,
                label: "Téléphone Mobile Money",
                hint: "Ex: +223 70 12 34 56",
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                camelColor: camelColor,
              ),
              const SizedBox(height: 14),
              _buildInputField(
                icon: Icons.lock_outline,
                label: ValidateurMotDePasse.libelleMotDePasse,
                hint: "Au moins 8 car. (1 maj, 1 min, 1 chiffre)",
                controller: _pinController,
                obscureText: _obscurePin,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(ValidateurMotDePasse.maxLongueur),
                ],
                camelColor: camelColor,
                trailing: IconButton(
                  icon: Icon(
                    _obscurePin
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: camelColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                ),
              ),
              const SizedBox(height: 14),
              _buildInputField(
                icon: Icons.lock_outline,
                label: ValidateurMotDePasse.libelleConfirmation,
                hint: "Répétez votre mot de passe à l'identique",
                controller: _confirmPinController,
                obscureText: _obscureConfirmPin,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(ValidateurMotDePasse.maxLongueur),
                ],
                camelColor: camelColor,
                trailing: IconButton(
                  icon: Icon(
                    _obscureConfirmPin
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: camelColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: estSombre ? const Color(0xFF2A231C) : const Color(0xFFFBF6F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: estSombre ? AppTheme.doreKaravan.withValues(alpha: 0.3) : const Color(0xFFE2CBB2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.doreKaravan,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Validation Courtier : après vérification SMS, vous déposerez votre pièce d'identité et votre licence de transitaire / commissionnaire agréé.",
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: estSombre ? const Color(0xFFE6D6C6) : const Color(0xFF6B5843),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
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
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.2),
                      )
                    : const Text(
                        "Créer mon compte courtier",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: Divider(color: AppTheme.couleurBordure(context), thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      "OU",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.couleurTexteAttenue(context),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppTheme.couleurBordure(context), thickness: 1)),
                ],
              ),
              const SizedBox(height: 18),
              const BoutonGoogleSignIn(
                role: RoleActeur.courtier,
                libelle: "S'inscrire avec Google",
                estInscription: true,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Vous avez déjà un compte courtier ? ",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.couleurTexteAttenue(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Text(
                      "Se connecter",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: camelColor,
                        decoration: TextDecoration.underline,
                        decorationColor: camelColor,
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

  Widget _buildInputField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required Color camelColor,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? trailing,
  }) {
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: couleurCarte,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: couleurBordure, width: 1.2),
        boxShadow: AppTheme.ombreDouce,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: couleurBordure, width: 1.1),
            ),
            child: Icon(icon, color: camelColor, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: couleurAttenue,
                  ),
                ),
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: couleurTexte,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: couleurAttenue,
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

