import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/role_acteur.dart';
import '../services/auth_service.dart';
import '../services/api/api_exception.dart';
import '../services/validateur_mot_de_passe.dart';
import 'commercant_inscription_screen.dart';

/// Écran de Connexion conforme au modèle Figma exact et aux specs backend (PIN)
class CommercantConnexionScreen extends StatefulWidget {
  final RoleActeur role;

  const CommercantConnexionScreen({
    super.key,
    this.role = RoleActeur.commercant,
  });

  @override
  State<CommercantConnexionScreen> createState() =>
      _CommercantConnexionScreenState();
}

class _CommercantConnexionScreenState extends State<CommercantConnexionScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _seConnecter() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Veuillez renseigner votre numéro de téléphone")),
      );
      return;
    }

    final erreurMdp = ValidateurMotDePasse.validerConnexion(pin);
    if (erreurMdp != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erreurMdp)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.connecter(telephone: phone, motDePasse: pin);
      if (!mounted) return;

      String route;
      switch (widget.role) {
        case RoleActeur.grossiste:
          route = '/grossiste';
          break;
        case RoleActeur.courtier:
          route = '/courtier';
          break;
        case RoleActeur.commercant:
          route = '/commercant';
          break;
      }

      Navigator.of(context).pushReplacementNamed(route);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.messageComplet
          : 'Erreur de connexion : ${e.toString()}';
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
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              Image.asset(
                'assets/images/logo_dogo.png',
                height: 64,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),

              // 1. TITRE PRINCIPAL FIGMA
              const Text(
                "Connexion",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1E24),
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 32),

              // 2. CHAMP TÉLÉPHONE FIGMA
              _buildFigmaInputField(
                icon: Icons.phone_outlined,
                label: "Téléphone",
                hint: "Entrez votre numéro de téléphone",
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                borderColor: borderColor,
                camelColor: camelColor,
              ),

              const SizedBox(height: 16),

              // 3. CHAMP MOT DE PASSE FIGMA
              _buildFigmaInputField(
                icon: Icons.lock_outline,
                label: "Mot de passe",
                hint: "Entrez votre mot de passe",
                controller: _pinController,
                obscureText: _obscurePin,
                borderColor: borderColor,
                camelColor: camelColor,
                trailing: IconButton(
                  icon: Icon(
                    _obscurePin
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: camelColor,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePin = !_obscurePin);
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 4. LIGNE "SE SOUVENIR DE MOI" & "MOT DE PASSE OUBLIÉ ?"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Case à cocher personnalisée
                  InkWell(
                    onTap: () {
                      setState(() => _rememberMe = !_rememberMe);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _rememberMe ? camelColor : Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: _rememberMe ? camelColor : borderColor,
                              width: 1.4,
                            ),
                          ),
                          child: _rememberMe
                              ? const Icon(Icons.check,
                                  size: 13, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Se souvenir de\nmoi",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF555555),
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lien mot de passe oublié
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Un SMS de réinitialisation de votre mot de passe vous a été envoyé."),
                          backgroundColor: camelColor,
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "Mot de passe oublié ?",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: camelColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 5. BOUTON PRINCIPAL "SE CONNECTER"
              ElevatedButton(
                onPressed: _isLoading ? null : _seConnecter,
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
                        "Se connecter",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),

              const SizedBox(height: 28),

              // 6. LIEN INFÉRIEUR "VOUS N'AVEZ PAS DE COMPTE ? INSCRIPTION"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Vous n'avez pas de compte ? ",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CommercantInscriptionScreen(role: widget.role),
                        ),
                      );
                    },
                    child: const Text(
                      "Inscription",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
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
