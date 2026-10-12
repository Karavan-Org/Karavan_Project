import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/role_acteur.dart';
import '../grossiste/grossiste_acces.dart';
import '../grossiste/grossiste_connexion_screen.dart';
import '../courtier/courtier_main_nav.dart';
import '../services/auth_service.dart';
import '../services/api/api_exception.dart';
import 'commercant_main_nav.dart';

/// Écran de Vérification OTP du compte conforme au modèle Figma exact
class CommercantOtpScreen extends StatefulWidget {
  final String numeroTelephone;
  final RoleActeur role;
  final String? codeSimulation;

  /// Mot de passe choisi à l'inscription : permet d'ouvrir la session juste après la vérification
  final String? motDePasse;
  final String? pin;

  const CommercantOtpScreen({
    super.key,
    this.numeroTelephone = "+223 70 12 34 56",
    this.role = RoleActeur.commercant,
    this.codeSimulation,
    this.motDePasse,
    this.pin,
  });

  @override
  State<CommercantOtpScreen> createState() => _CommercantOtpScreenState();
}

class _CommercantOtpScreenState extends State<CommercantOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  int _secondesRestantes = 45;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _demarrerTimer();
    // Pré-remplir automatiquement le code en mode simulation/test
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Le backend ne renvoie le code qu'en profil demo (dogo.otp.afficher-dans-reponse)
      final codeToFill = widget.codeSimulation ?? '';
      if (codeToFill.length >= 4) {
        for (int i = 0; i < 4; i++) {
          _controllers[i].text = codeToFill[i];
        }
      }
    });
  }

  void _demarrerTimer() {
    _timer?.cancel();
    setState(() => _secondesRestantes = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondesRestantes > 0) {
        setState(() => _secondesRestantes--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verifierOtp() async {
    final code = _controllers.map((c) => c.text.trim()).join();

    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir le code à 4 chiffres reçu par SMS")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.verifierOtp(
        telephone: widget.numeroTelephone,
        code: code,
      );
      if (!mounted) return;

      Widget destination;
      switch (widget.role) {
        case RoleActeur.grossiste:
          // Le compte attend son dossier KYC (RG-03) : on ouvre la session pour le déposer
          final secret = widget.motDePasse ?? widget.pin;
          if (secret != null) {
            final profil = await AuthService.instance.connecter(
              telephone: widget.numeroTelephone,
              motDePasse: secret,
              pin: secret,
            );
            destination = await ecranGrossisteSelonDossier(profil);
          } else {
            destination = const GrossisteConnexionScreen();
          }
          if (!mounted) return;
          break;
        case RoleActeur.courtier:
          destination = const CourtierMainNav();
          break;
        case RoleActeur.commercant:
          destination = const CommercantMainNav();
          break;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.messageComplet : 'Code invalide : ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFC0392B),
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

    final timerText = "00:${_secondesRestantes.toString().padLeft(2, '0')}";

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
              const SizedBox(height: 20),

              // 1. ICÔNE BOUCLIER CAMEL FIGMA AVEC COCHE
              const SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shield,
                      size: 74,
                      color: Color(0xFF9E6E4B),
                    ),
                    Positioned(
                      top: 20,
                      child: Icon(
                        Icons.check_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. TITRE & SOUS-TITRE FIGMA
              const Text(
                "Vérification du compte",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1E24),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: "Nous avons envoyé un code de vérification\n",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B6B6B),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(text: "au "),
                    TextSpan(
                      text: widget.numeroTelephone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1E24),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // BANIÈRE MODE DÉMO : seulement si le serveur a renvoyé le code
              if (widget.codeSimulation != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_outlined, color: Color(0xFF2E7D32), size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Code de test (mode démo) : ${widget.codeSimulation}",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. LES 4 CASES DE SAISIE DU CODE OTP FIGMA
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: 58,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0846321E),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E1E24),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          counterText: "",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          if (val.isNotEmpty && index < 3) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (val.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 38),

              // 4. BOUTON PRINCIPAL "VÉRIFIER"
              ElevatedButton(
                onPressed: _isLoading ? null : _verifierOtp,
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
                        "Vérifier",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),

              const SizedBox(height: 22),

              // 5. LIEN "RENVOYER LE CODE (00:45)"
              TextButton(
                onPressed: _secondesRestantes == 0
                    ? () {
                        _demarrerTimer();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Un nouveau code SMS vous a été envoyé."),
                            backgroundColor: camelColor,
                          ),
                        );
                      }
                    : null,
                child: Text(
                  _secondesRestantes > 0
                      ? "Renvoyer le code ($timerText)"
                      : "Renvoyer le code maintenant",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _secondesRestantes > 0 ? const Color(0xFFC7844D) : camelColor,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
