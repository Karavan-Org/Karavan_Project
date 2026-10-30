import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../commercant/commercant_main_nav.dart';
import '../grossiste/grossiste_acces.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/session_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bouton_bascule_theme.dart';

/// Écran « Complétez votre profil » après authentification Google OAuth2 (RG-07).
/// Conserve le rôle déjà choisi à l'entrée de l'application sans redemander de choix :
/// - Commerçant : accès direct à l'espace après l'OTP (aucune validation KYC).
/// - Grossiste / Courtier : soumis à validation selon leurs critères respectifs (dépôt des justificatifs KYC).
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

  bool _otpEnvoye = false;
  bool _enCours = false;
  String? _messageErreur;

  int _secondesRestantes = 60;
  Timer? _timer;

  RoleActeur get _roleChoisi => widget.roleParDefaut;

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
      await AuthService.instance.demanderOtpGoogleCompleter(
        jetonInscription: widget.jetonInscription,
        telephone: tel,
        typeActeur: _roleChoisi.codeBackend,
      );

      for (final c in _otpControllers) {
        c.clear();
      }

      setState(() {
        _otpEnvoye = true;
      });

      _demarrerTimer();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _otpFocusNodes.first.requestFocus();
        }
      });
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
        typeActeur: _roleChoisi.codeBackend,
      );

      await SessionStorageService.instance.reinitialiserTousLesGuides();
      if (!mounted) return;

      final roleEffectif = profil.roleActeur;
      if (roleEffectif != _roleChoisi) {
        await AuthService.instance.deconnecter();
        if (!mounted) return;
        setState(() {
          _messageErreur =
              "Ce numéro est déjà rattaché à un compte ${roleEffectif.libelle} et ne peut pas être utilisé dans l'espace ${_roleChoisi.libelle}.";
        });
        return;
      }

      if (roleEffectif == RoleActeur.commercant) {
        // Le commerçant n'a pas besoin d'être validé : accès immédiat à son espace
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CommercantMainNav()),
          (r) => false,
        );
        return;
      }

      // Grossiste et Courtier : soumis à validation selon leurs critères respectifs (KYC)
      final destination = await ecranSelonStatut(profil, roleEffectif);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (r) => false,
      );
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
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  switch (_roleChoisi) {
                                    RoleActeur.commercant => Icons.storefront_rounded,
                                    RoleActeur.grossiste => Icons.inventory_2_rounded,
                                    RoleActeur.courtier => Icons.local_shipping_rounded,
                                  },
                                  size: 13,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Compte ${_roleChoisi.libelle}",
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Rappel des critères de validation uniquement pour Grossiste et Courtier (le Commerçant n'est pas soumis à validation)
              if (_roleChoisi.exigeValidation) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.estSombre(context)
                        ? const Color(0xFF2A231C)
                        : const Color(0xFFFBF6F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.estSombre(context)
                          ? AppTheme.doreKaravan.withValues(alpha: 0.3)
                          : const Color(0xFFE2CBB2),
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
                          "Après confirmation de votre numéro, vous déposerez vos pièces justificatives (${_roleChoisi.criteresValidation}) pour validation de votre compte ${_roleChoisi.libelle.toLowerCase()}.",
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.estSombre(context)
                                ? const Color(0xFFE6D6C6)
                                : const Color(0xFF6B5843),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

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
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: null,
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
                      : Text(
                          _roleChoisi.exigeValidation
                              ? "Valider et continuer"
                              : "Valider et accéder à Karavan",
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
