import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bouton_bascule_theme.dart';

/// Écran « Complétez votre profil » après authentification Google.
/// 1. Saisie du numéro de téléphone malien (+223).
/// 2. Envoi du code OTP par SMS.
/// 3. Saisie du code de vérification (compte à rebours 60 s et renvoi).
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
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _demarrerCompteARebours() {
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

  Future<void> _demanderCodeOtp() async {
    final telBrut = _phoneController.text.trim();
    final telNettoye = telBrut.replaceAll(RegExp(r'\s+'), '');

    if (telNettoye.length < 8) {
      setState(() => _messageErreur = "Veuillez entrer un numéro de téléphone malien valide (8 chiffres).");
      return;
    }

    setState(() {
      _enCours = true;
      _messageErreur = null;
    });

    try {
      final rep = await AuthService.instance.demanderOtpGoogleCompleter(
        jetonInscription: widget.jetonInscription,
        telephone: telNettoye,
      );

      setState(() {
        _enCours = false;
        _otpEnvoye = true;
        _codeOtpDemo = rep['codeOtp']?.toString();
      });

      _demarrerCompteARebours();

      // Pré-remplissage en mode démo si le code est fourni par le backend
      if (_codeOtpDemo != null && _codeOtpDemo!.isNotEmpty) {
        for (int i = 0; i < _codeOtpDemo!.length && i < 4; i++) {
          _otpControllers[i].text = _codeOtpDemo![i];
        }
      }
    } on ApiException catch (e) {
      setState(() {
        _enCours = false;
        _messageErreur = e.messageComplet;
      });
    } catch (e) {
      setState(() {
        _enCours = false;
        _messageErreur = "Erreur lors de l'envoi du SMS : $e";
      });
    }
  }

  Future<void> _validerOtpEtTerminer() async {
    final codeSaisi = _otpControllers.map((c) => c.text.trim()).join();
    if (codeSaisi.length != 4) {
      setState(() => _messageErreur = "Veuillez saisir les 4 chiffres du code de vérification SMS.");
      return;
    }

    final telBrut = _phoneController.text.trim();
    final telNettoye = telBrut.replaceAll(RegExp(r'\s+'), '');

    setState(() {
      _enCours = true;
      _messageErreur = null;
    });

    try {
      final profil = await AuthService.instance.completerGoogleEtConnecter(
        jetonInscription: widget.jetonInscription,
        telephone: telNettoye,
        codeOtp: codeSaisi,
        typeActeur: _roleSelectionne.name.toUpperCase(),
      );

      if (!mounted) return;

      final roleEffectif = profil.roleActeur;
      if (roleEffectif != _roleSelectionne) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Compte existant rattaché : vous êtes connecté à votre espace ${roleEffectif.libelle}.",
            ),
            backgroundColor: AppTheme.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      final route = switch (roleEffectif) {
        RoleActeur.grossiste => '/grossiste',
        RoleActeur.courtier => '/courtier',
        RoleActeur.commercant => '/commercant',
      };
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } on ApiException catch (e) {
      setState(() {
        _enCours = false;
        _messageErreur = e.messageComplet;
      });
    } catch (e) {
      setState(() {
        _enCours = false;
        _messageErreur = "Erreur lors de la finalisation du profil : $e";
      });
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: couleurTexte, size: 22),
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
                // Carte du compte Google validé
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
                        backgroundColor: const Color(0xFF4285F4),
                        backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                            ? NetworkImage(widget.photoUrl!)
                            : null,
                        child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                            ? Text(
                                (widget.nom != null && widget.nom!.isNotEmpty) ? widget.nom![0].toUpperCase() : "G",
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
                                    widget.nom ?? "Utilisateur Google",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: couleurTexte),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF34A853), size: 18),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.email ?? "Email Google vérifié",
                              style: TextStyle(fontSize: 12.5, color: couleurAttenue, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                if (!_otpEnvoye) ...[
                  // Étape 1 : Numéro de téléphone malien (+223)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.doreKaravan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.doreKaravan.withValues(alpha: 0.35), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.security_rounded, color: AppTheme.doreKaravan, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Pour sécuriser vos achats groupés, vos retraits au dépôt de Bamako et vos transactions Mobile Money (Orange Money, Wave, Moov), veuillez confirmer votre numéro malien.",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: couleurTexte, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Numéro de téléphone (+223)",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: couleurTexte),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: couleurCarte,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _messageErreur != null ? AppTheme.danger : couleurBordure, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android_rounded, color: AppTheme.bissap, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+]'))],
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: couleurTexte),
                            decoration: const InputDecoration(
                              hintText: "+223 70 00 00 00",
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _enCours ? null : _demanderCodeOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.bissap,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _enCours
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                          : const Text("Recevoir mon code SMS", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ] else ...[
                  // Étape 2 : Saisie du code OTP (6 cases)
                  Text(
                    "Code de vérification SMS",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: couleurTexte),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Entrez le code envoyé au ${_phoneController.text.trim()}",
                    style: TextStyle(fontSize: 12.5, color: couleurAttenue, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // 4 cases de code OTP (Code SMS Karavan à 4 chiffres)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Container(
                        width: 54,
                        height: 58,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: couleurCarte,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: couleurBordure, width: 1.5),
                        ),
                        child: Center(
                          child: TextFormField(
                            controller: _otpControllers[index],
                            focusNode: _otpFocusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: couleurTexte),
                            decoration: const InputDecoration(counterText: "", border: InputBorder.none),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (val) {
                              if (val.isNotEmpty && index < 3) {
                                _otpFocusNodes[index + 1].requestFocus();
                              } else if (val.isEmpty && index > 0) {
                                _otpFocusNodes[index - 1].requestFocus();
                              }
                              if (index == 3 && val.isNotEmpty) {
                                _validerOtpEtTerminer();
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 18),

                  // Compte à rebours 60s et renvoi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: couleurAttenue),
                      const SizedBox(width: 6),
                      Text(
                        _secondesRestantes > 0 ? "Renvoyer dans ${_secondesRestantes}s" : "Code non reçu ?",
                        style: TextStyle(fontSize: 12.5, color: couleurAttenue, fontWeight: FontWeight.w600),
                      ),
                      if (_secondesRestantes == 0) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _enCours ? null : _demanderCodeOtp,
                          child: const Text("Renvoyer le SMS", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.bissap)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _enCours ? null : _validerOtpEtTerminer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.bissap,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _enCours
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                          : const Text("Confirmer et accéder à mon espace", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () => setState(() => _otpEnvoye = false),
                    child: const Text("Modifier le numéro de téléphone", style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.bissap)),
                  ),
                ],

                if (_messageErreur != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _messageErreur!,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

