import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bouton_bascule_theme.dart';

/// Écran « Complétez votre profil » après authentification Auth0.
/// 1. Saisie du numéro de téléphone malien (+223).
/// 2. Envoi du code OTP par SMS.
/// 3. Saisie du code de vérification (compte à rebours 60 s et renvoi).
/// 4. Finalisation de la session et accès direct à l'espace Karavan.
class Auth0CompleterProfilScreen extends StatefulWidget {
  final String jetonInscription;
  final String? sub;
  final String? email;
  final bool emailVerified;
  final String? nom;
  final String? photoUrl;
  final RoleActeur roleParDefaut;

  const Auth0CompleterProfilScreen({
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
  State<Auth0CompleterProfilScreen> createState() => _Auth0CompleterProfilScreenState();
}

class _Auth0CompleterProfilScreenState extends State<Auth0CompleterProfilScreen> {
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
      final res = await AuthService.instance.demanderOtpAuth0Completer(
        jetonInscription: widget.jetonInscription,
        telephone: tel,
      );

      setState(() {
        _otpEnvoye = true;
        _codeOtpDemo = res['codeOtp']?.toString();
      });

      _demarrerTimer();

      // Pré-remplir le code en démo
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
      final profil = await AuthService.instance.completerAuth0EtConnecter(
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
            "Complétez votre profil",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ),
        centerTitle: true,
        actions: const [
          Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: BoutonBasculeTheme(compact: true),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Carte du compte Auth0 validé
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: couleurCarte,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: couleurBordure, width: 1.2),
                    boxShadow: AppTheme.ombreDouce,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFEB5424), // Orange officiel Auth0
                        backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                            ? NetworkImage(widget.photoUrl!)
                            : null,
                        child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                            ? Text(
                                (widget.nom != null && widget.nom!.isNotEmpty) ? widget.nom![0].toUpperCase() : "A",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.nom ?? "Utilisateur Auth0",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: couleurTexte),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 18),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.email ?? "Email Auth0 vérifié",
                              style: TextStyle(fontSize: 12.5, color: couleurAttenue, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  "Associer votre numéro de téléphone",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleurTexte),
                ),
                const SizedBox(height: 6),
                Text(
                  "Pour sécuriser vos commandes Karavan, chaque compte doit être lié à un numéro malien vérifié par SMS.",
                  style: TextStyle(fontSize: 13, color: couleurAttenue, height: 1.4),
                ),

                const SizedBox(height: 20),

                // Sélecteur de rôle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: couleurCarte,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: couleurBordure),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RoleActeur>(
                      value: _roleSelectionne,
                      isExpanded: true,
                      dropdownColor: couleurCarte,
                      items: const [
                        DropdownMenuItem(
                          value: RoleActeur.commercant,
                          child: Text("Commerçant (Boutique / Détaillant)"),
                        ),
                        DropdownMenuItem(
                          value: RoleActeur.grossiste,
                          child: Text("Grossiste (Fournisseur d'arrivages)"),
                        ),
                        DropdownMenuItem(
                          value: RoleActeur.courtier,
                          child: Text("Courtier (Transit & Logistique)"),
                        ),
                      ],
                      onChanged: _otpEnvoye ? null : (r) {
                        if (r != null) setState(() => _roleSelectionne = r);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Champ Téléphone
                TextField(
                  controller: _phoneController,
                  enabled: !_otpEnvoye,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: couleurTexte),
                  decoration: InputDecoration(
                    labelText: "Numéro de téléphone",
                    labelStyle: TextStyle(color: couleurAttenue),
                    prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppTheme.primary),
                    filled: true,
                    fillColor: couleurCarte,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: couleurBordure)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: couleurBordure)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                  ),
                ),

                if (_otpEnvoye) ...[
                  const SizedBox(height: 24),
                  Text(
                    "Code de vérification SMS (4 chiffres)",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: couleurTexte),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (index) {
                      return SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: couleurTexte),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            counterText: "",
                            filled: true,
                            fillColor: couleurCarte,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                          ),
                          onChanged: (val) {
                            if (val.isNotEmpty && index < 3) {
                              _otpFocusNodes[index + 1].requestFocus();
                            } else if (val.isEmpty && index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _secondesRestantes > 0 ? "Renvoyer dans ${_secondesRestantes}s" : "Code non reçu ?",
                        style: TextStyle(fontSize: 12.5, color: couleurAttenue),
                      ),
                      TextButton(
                        onPressed: (_secondesRestantes == 0 && !_enCours) ? _demanderOtp : null,
                        child: const Text("Renvoyer le code", style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],

                if (_messageErreur != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_messageErreur!, style: const TextStyle(color: AppTheme.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _enCours ? null : (_otpEnvoye ? _validerOtpEtFinaliser : _demanderOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _enCours
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _otpEnvoye ? "Valider et rejoindre Karavan" : "Envoyer le code par SMS",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Rétrocompatibilité
typedef GoogleCompleterProfilScreen = Auth0CompleterProfilScreen;
