import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../services/validateur_mot_de_passe.dart';

/// Modal sécurisé de réinitialisation de mot de passe par vérification SMS OTP (RG-07),
/// isolé par espace (Commerçant, Grossiste, Courtier).
class MotDePasseOublieModal extends StatefulWidget {
  final String? initialTelephone;
  final RoleActeur? role;
  final ValueChanged<String>? onMotDePasseReinitialise;

  const MotDePasseOublieModal({
    super.key,
    this.initialTelephone,
    this.role,
    this.onMotDePasseReinitialise,
  });

  static Future<void> ouvrir(
    BuildContext context, {
    String? initialTelephone,
    RoleActeur? role,
    ValueChanged<String>? onMotDePasseReinitialise,
  }) {
    final largeEcran = MediaQuery.of(context).size.width >= 600;
    if (largeEcran) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: MotDePasseOublieModal(
              initialTelephone: initialTelephone,
              role: role,
              onMotDePasseReinitialise: onMotDePasseReinitialise,
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MotDePasseOublieModal(
        initialTelephone: initialTelephone,
        role: role,
        onMotDePasseReinitialise: onMotDePasseReinitialise,
      ),
    );
  }

  @override
  State<MotDePasseOublieModal> createState() => _MotDePasseOublieModalState();
}

class _MotDePasseOublieModalState extends State<MotDePasseOublieModal> {
  int _etape = 1; // 1 = Saisie téléphone, 2 = Saisie OTP et nouveau mot de passe
  late final TextEditingController _telController;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _mdpController = TextEditingController();
  final TextEditingController _confirmerMdpController = TextEditingController();

  bool _chargement = false;
  bool _masquerMdp = true;
  bool _masquerConfirmerMdp = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final init = widget.initialTelephone?.trim() ?? '';
    _telController = TextEditingController(
      text: init.isNotEmpty ? (init.startsWith('+223') ? init : '+223 $init') : '+223 ',
    );
  }

  @override
  void dispose() {
    _telController.dispose();
    _otpController.dispose();
    _mdpController.dispose();
    _confirmerMdpController.dispose();
    super.dispose();
  }

  String get _telNettoye => _telController.text.replaceAll(RegExp(r'\s+'), '');

  Future<void> _demanderCodeOtp() async {
    final tel = _telNettoye;
    if (tel.length < 8) {
      setState(() => _erreur = "Veuillez saisir un numéro de téléphone valide.");
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      await AuthService.instance.demanderReinitialisationMotDePasse(
        telephone: tel,
        typeActeur: widget.role?.codeBackend,
      );
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _etape = 2;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e is ApiException ? e.messageComplet : "Impossible d'envoyer le code SMS. Veuillez vérifier votre connexion.";
      });
    }
  }

  Future<void> _confirmerReinitialisation() async {
    final codeOtp = _otpController.text.trim();
    final nouveauMdp = _mdpController.text;
    final confirmerMdp = _confirmerMdpController.text;

    if (codeOtp.length < 4) {
      setState(() => _erreur = "Veuillez saisir le code de vérification à 4 chiffres reçu par SMS.");
      return;
    }

    final erreurFormat = ValidateurMotDePasse.validerCreation(nouveauMdp);
    if (erreurFormat != null) {
      setState(() => _erreur = erreurFormat);
      return;
    }

    if (nouveauMdp != confirmerMdp) {
      setState(() => _erreur = "Les deux mots de passe ne correspondent pas.");
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      await AuthService.instance.reinitialiserMotDePasse(
        telephone: _telNettoye,
        code: codeOtp,
        nouveauMotDePasse: nouveauMdp,
        typeActeur: widget.role?.codeBackend,
      );
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Mot de passe réinitialisé avec succès ! Vous pouvez maintenant vous connecter.",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.couleurSucces(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );

      if (widget.onMotDePasseReinitialise != null) {
        widget.onMotDePasseReinitialise!(_telNettoye);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e is ApiException ? e.messageComplet : "Impossible de réinitialiser le mot de passe. Veuillez vérifier le code saisi.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = AppTheme.estSombre(context);
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);

    return Container(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      decoration: BoxDecoration(
        color: couleurCarte,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: couleurBordure, width: 1.2),
        boxShadow: AppTheme.ombreDouce,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre d'accroche supérieure
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: couleurBordure,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // En-tête
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppTheme.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _etape == 1 ? "Mot de passe oublié" : "Nouveau mot de passe",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: couleurTexte,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _etape == 1
                            ? (widget.role != null
                                ? "Espace ${widget.role!.libelle} • Récupération par SMS"
                                : "Récupération sécurisée par SMS OTP")
                            : "Vérification OTP & mise à jour",
                        style: TextStyle(fontSize: 12, color: couleurAttenue),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: "Fermer",
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_erreur != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _erreur!,
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_etape == 1) ...[
              Text(
                "Entrez votre numéro de téléphone. Un code de vérification à 4 chiffres vous sera envoyé par SMS pour réinitialiser votre mot de passe.",
                style: TextStyle(fontSize: 13, color: couleurAttenue, height: 1.4),
              ),
              const SizedBox(height: 18),

              // Champ Téléphone
              Text(
                "Numéro de téléphone Malien (+223)",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: couleurTexte),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _telController,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: couleurTexte),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppTheme.secondary, size: 20),
                  hintText: "+223 70 00 00 00",
                  filled: true,
                  fillColor: estSombre ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9F9F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.secondary, width: 2)),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton Suivant
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _chargement ? null : _demanderCodeOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  child: _chargement
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sms_outlined, size: 20),
                            SizedBox(width: 10),
                            Text("Envoyer le code SMS", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
            ] else ...[
              // Étape 2 : OTP & Nouveau mot de passe
              Text(
                "Saisissez le code à 4 chiffres envoyé par SMS au ${_telController.text.trim()}.",
                style: TextStyle(fontSize: 13, color: couleurAttenue, height: 1.4),
              ),
              const SizedBox(height: 14),

              // Champ OTP
              Text(
                "Code de vérification SMS (4 chiffres)",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: couleurTexte),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 6, color: couleurTexte),
                decoration: InputDecoration(
                  counterText: "",
                  prefixIcon: const Icon(Icons.pin_rounded, color: AppTheme.secondary, size: 20),
                  hintText: "••••",
                  hintStyle: const TextStyle(letterSpacing: 4),
                  filled: true,
                  fillColor: estSombre ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9F9F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.secondary, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Champ Nouveau Mot de passe
              Text(
                "Nouveau mot de passe",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: couleurTexte),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mdpController,
                obscureText: _masquerMdp,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: couleurTexte),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.secondary, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_masquerMdp ? Icons.visibility_off : Icons.visibility, color: couleurAttenue, size: 20),
                    onPressed: () => setState(() => _masquerMdp = !_masquerMdp),
                  ),
                  hintText: "8+ car., maj., min., chiffre",
                  filled: true,
                  fillColor: estSombre ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9F9F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.secondary, width: 2)),
                ),
              ),
              const SizedBox(height: 14),

              // Confirmer le nouveau mot de passe
              Text(
                "Confirmer le mot de passe",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: couleurTexte),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmerMdpController,
                obscureText: _masquerConfirmerMdp,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: couleurTexte),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.secondary, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_masquerConfirmerMdp ? Icons.visibility_off : Icons.visibility, color: couleurAttenue, size: 20),
                    onPressed: () => setState(() => _masquerConfirmerMdp = !_masquerConfirmerMdp),
                  ),
                  hintText: "Confirmez votre nouveau mot de passe",
                  filled: true,
                  fillColor: estSombre ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9F9F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: couleurBordure)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.secondary, width: 2)),
                ),
              ),
              const SizedBox(height: 24),

              // Boutons Action
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _chargement ? null : () => setState(() => _etape = 1),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: couleurBordure),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Retour"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _chargement ? null : _confirmerReinitialisation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 1,
                      ),
                      child: _chargement
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                          : const Text("Valider", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

