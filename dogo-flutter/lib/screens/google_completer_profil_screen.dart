import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bouton_bascule_theme.dart';

/// Écran « Complétez votre profil » après authentification Google OAuth2 (RG-07).
/// 1. Saisie du numéro de téléphone malien (+223).
/// 2. Envoi du code OTP par SMS.
/// 3. Saisie du code de vérification à 4 chiffres.
/// 4. Finalisation de la session et accès direct à l'espace Karavan.
class GoogleCompleterProfilScreen extends StatefulWidget {
  final String jetonInscription;
  final String? sub;
  final String? email;
  final bool emailVerified;
  final String? nom;
  final String? photoUrl;
  final RoleActeur roleParDefaut;

  const GoogleCompleterProfilScreen({
    super.key,
    required this.jetonInscription,
    this.sub,
    this.email,
    this.emailVerified = true,
    this.nom,
    this.photoUrl,
    this.roleParDefaut = RoleActeur.commercant,
  });

  @override
  State<GoogleCompleterProfilScreen> createState() => _GoogleCompleterProfilScreenState();
}

class _GoogleCompleterProfilScreenState extends State<GoogleCompleterProfilScreen> {
  final TextEditingController _phoneController = TextEditingController(text: "+223 ");
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  late RoleActeur _roleSelectionne;
  bool _otpEnvoye = false;
  bool _enCours = false;
  String? _messageErreur;
  String? _codeOtpDemo;

  int _secondesRestantes = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _roleSelectionne = widget.roleParDefaut;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _demarrerTimer() {
    _timer?.cancel();
    setState(() => _secondesRestantes = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondesRestantes > 0) {
        setState(() => _secondesRestantes--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _demanderOtp() async {
    final tel = _phoneController.text.trim();
    final digits = tel.replaceAll(RegExp(r'\D'), '');
    if (!digits.startsWith('223') || digits.length != 11) {
      setState(() => _messageErreur = "Veuillez saisir un numéro malien valide à 8 chiffres après +223.");
      return;
    }

    setState(() {
      _enCours = true;
      _messageErreur = null;
    });

    try {
      final res = await AuthService.instance.demanderOtpGoogleCompleter(
        jetonInscription: widget.jetonInscription,
        telephone: tel,
      );

      setState(() {
        _otpEnvoye = true;
        _codeOtpDemo = res['codeOtp']?.toString();
      });

      _demarrerTimer();

      // Pré-remplir le code en mode démo / test local si renvoyé
      if (_codeOtpDemo != null && _codeOtpDemo!.length == 4) {
        for (int i = 0; i < 4; i++) {
          _otpControllers[i].text = _codeOtpDemo![i];
        }
      }
    } on ApiException catch (e) {
      setState(() => _messageErreur = e.messageComplet);
    } catch (_) {
      setState(() => _messageErreur = "Impossible d'envoyer le code SMS. Vérifiez votre connexion.");
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _validerOtpEtFinaliser() async {
    final code = _otpControllers.map((c) => c.text.trim()).join();
    if (code.length != 4) {
      setState(() => _messageErreur = "Veuillez saisir les 4 chiffres du code SMS.");
      return;
    }

    setState(() {
      _enCours = true;
      _messageErreur = null;
    });

    try {
      final profil = await AuthService.instance.completerGoogleEtConnecter(
        jetonInscription: widget.jetonInscription,
        telephone: _phoneController.text.trim(),
        codeOtp: code,
        typeActeur: _roleSelectionne.codeBackend,
      );

      if (!mounted) return;

      final roleEffectif = profil.roleActeur;
      final route = switch (roleEffectif) {
        RoleActeur.grossiste => '/grossiste',
        RoleActeur.courtier => '/courtier',
        RoleActeur.commercant => '/commercant',
      };

      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    } on ApiException catch (e) {
      setState(() => _messageErreur = e.messageComplet);
    } catch (_) {
      setState(() => _messageErreur = "Échec de validation du code. Veuillez réessayer.");
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: couleurTexte),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "Finaliser votre compte",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        actions: const [
          BoutonBasculeTheme(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge récapitulatif du compte Google
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: couleurCarte,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: couleurBordure),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      backgroundImage: (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                          ? NetworkImage(widget.photoUrl!)
                          : null,
                      child: (widget.photoUrl == null || widget.photoUrl!.isEmpty)
                          ? const Icon(Icons.person, color: AppTheme.primary, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.nom ?? "Compte Google",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: couleurTexte,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.email ?? "Email vérifié",
                            style: TextStyle(
                              fontSize: 13,
                              color: couleurAttenue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sélecteur de rôle si non encore figé
              Text(
                "Votre activité sur Karavan",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: couleurTexte,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<RoleActeur>(
                segments: const [
                  ButtonSegment(
                    value: RoleActeur.commercant,
                    label: Text("Commerçant", style: TextStyle(fontSize: 12.5)),
                    icon: Icon(Icons.storefront_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: RoleActeur.grossiste,
                    label: Text("Grossiste", style: TextStyle(fontSize: 12.5)),
                    icon: Icon(Icons.inventory_2_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: RoleActeur.courtier,
                    label: Text("Courtier", style: TextStyle(fontSize: 12.5)),
                    icon: Icon(Icons.local_shipping_rounded, size: 16),
                  ),
                ],
                selected: {_roleSelectionne},
                onSelectionChanged: (val) {
                  setState(() => _roleSelectionne = val.first);
                },
              ),
              const SizedBox(height: 24),

              // Saisie du numéro malien
              Text(
                "Numéro de téléphone malien (+223)",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: couleurTexte,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_otpEnvoye && !_enCours,
                decoration: InputDecoration(
                  hintText: "+223 75 00 00 01",
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  suffixIcon: _otpEnvoye
                      ? IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          tooltip: "Modifier le numéro",
                          onPressed: () => setState(() => _otpEnvoye = false),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // Message d'erreur
              if (_messageErreur != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _messageErreur!,
                          style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Si OTP non envoyé : bouton demander code SMS
              if (!_otpEnvoye) ...[
                ElevatedButton(
                  onPressed: _enCours ? null : _demanderOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _enCours
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : const Text(
                          "Recevoir le code par SMS",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ] else ...[
                // Zone de saisie du code OTP
                const SizedBox(height: 8),
                Text(
                  "Code de vérification reçu par SMS",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: couleurTexte,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    return SizedBox(
                      width: 58,
                      height: 60,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) {
                          if (val.isNotEmpty && index < 3) {
                            _otpFocusNodes[index + 1].requestFocus();
                          } else if (val.isEmpty && index > 0) {
                            _otpFocusNodes[index - 1].requestFocus();
                          }
                          if (_otpControllers.every((c) => c.text.isNotEmpty)) {
                            _validerOtpEtFinaliser();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Renvoi d'OTP avec timer
                Center(
                  child: _secondesRestantes > 0
                      ? Text(
                          "Renvoyer le code dans $_secondesRestantes s",
                          style: TextStyle(color: couleurAttenue, fontSize: 13),
                        )
                      : TextButton(
                          onPressed: _enCours ? null : _demanderOtp,
                          child: const Text("Renvoyer le code SMS"),
                        ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _enCours ? null : _validerOtpEtFinaliser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _enCours
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : const Text(
                          "Valider et accéder à Karavan",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
