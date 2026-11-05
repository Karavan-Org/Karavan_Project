import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/validateur_mot_de_passe.dart';
import '../theme/app_theme.dart';

/// Ouvre la boîte de dialogue élégante pour modifier le mot de passe du compte.
/// Accessible depuis les paramètres de tous les acteurs (Commerçant, Grossiste, Courtier).
Future<bool?> afficherDialogueChangerMotDePasse(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const SafeArea(
      top: false,
      child: ChangerMotDePasseSheet(),
    ),
  );
}

class ChangerMotDePasseSheet extends StatefulWidget {
  const ChangerMotDePasseSheet({super.key});

  @override
  State<ChangerMotDePasseSheet> createState() => _ChangerMotDePasseSheetState();
}

class _ChangerMotDePasseSheetState extends State<ChangerMotDePasseSheet> {
  final _ancienController = TextEditingController();
  final _nouveauController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _masquerAncien = true;
  bool _masquerNouveau = true;
  bool _masquerConfirmation = true;

  bool _chargement = false;
  String? _erreurGlobale;

  @override
  void dispose() {
    _ancienController.dispose();
    _nouveauController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _sauvegarder() async {
    setState(() => _erreurGlobale = null);

    final ancien = _ancienController.text.trim();
    final nouveau = _nouveauController.text.trim();
    final confirmation = _confirmationController.text.trim();

    if (ancien.isEmpty) {
      setState(
          () => _erreurGlobale = "Veuillez saisir votre mot de passe actuel");
      return;
    }

    final erreurCreation = ValidateurMotDePasse.validerCreation(nouveau);
    if (erreurCreation != null) {
      setState(() => _erreurGlobale = erreurCreation);
      return;
    }

    final erreurConf =
        ValidateurMotDePasse.validerConfirmation(nouveau, confirmation);
    if (erreurConf != null) {
      setState(() => _erreurGlobale = erreurConf);
      return;
    }

    if (ancien == nouveau) {
      setState(() => _erreurGlobale =
          "Le nouveau mot de passe doit être différent de l'actuel");
      return;
    }

    setState(() => _chargement = true);

    try {
      await AuthService.instance.changerMotDePasse(
        ancienMotDePasse: ancien,
        nouveauMotDePasse: nouveau,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                  child: Text("Votre mot de passe a été modifié avec succès")),
            ],
          ),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.messageComplet
          : "Erreur lors de la modification : $e";
      setState(() => _erreurGlobale = msg);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final bottomPadding = bottomInset > 0 ? bottomInset + 16 : systemBottom + 24;
    final camelColor = AppTheme.estSombre(context) ? AppTheme.darkPrimary : AppTheme.bissap;
    final borderColor = AppTheme.couleurBordure(context);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: bottomPadding,
      ),
      decoration: BoxDecoration(
        color: AppTheme.couleurSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F2C241E), blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre supérieure d'accroche
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.bordureForte,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // En-tête
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Modifier le mot de passe",
                        style: TextStyle(fontFamily: AppTheme.policeTitre, 
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.couleurTexte(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Sécurisez l'accès à votre compte",
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.couleurTexteAttenue(context)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppTheme.couleurTexteAttenue(context)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message d'erreur s'il y a lieu
            if (_erreurGlobale != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.dangerClair,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dangerBordure),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _erreurGlobale!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Champ Ancien mot de passe
            _champMotDePasse(
              label: "Ancien mot de passe",
              hint: "Saisissez votre mot de passe actuel",
              controller: _ancienController,
              masque: _masquerAncien,
              onToggleMasque: () =>
                  setState(() => _masquerAncien = !_masquerAncien),
              borderColor: borderColor,
              camelColor: camelColor,
            ),
            const SizedBox(height: 14),

            // 2. Champ Nouveau mot de passe
            _champMotDePasse(
              label: ValidateurMotDePasse.libelleMotDePasse,
              hint: "Nouveau mot de passe (8 car. min)",
              controller: _nouveauController,
              masque: _masquerNouveau,
              onToggleMasque: () =>
                  setState(() => _masquerNouveau = !_masquerNouveau),
              borderColor: borderColor,
              camelColor: camelColor,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),

            // Checklist dynamique des exigences de sécurité
            _buildChecklistSecurite(_nouveauController.text),
            const SizedBox(height: 14),

            // 3. Champ Confirmer le mot de passe
            _champMotDePasse(
              label: ValidateurMotDePasse.libelleConfirmation,
              hint: "Répétez le nouveau mot de passe",
              controller: _confirmationController,
              masque: _masquerConfirmation,
              onToggleMasque: () =>
                  setState(() => _masquerConfirmation = !_masquerConfirmation),
              borderColor: borderColor,
              camelColor: camelColor,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _chargement ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.bordureForte),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Annuler",
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _chargement ? null : _sauvegarder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _chargement
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            "Enregistrer le mot de passe",
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _champMotDePasse({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool masque,
    required VoidCallback onToggleMasque,
    required Color borderColor,
    required Color camelColor,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.couleurTexte(context)),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.couleurSurfaceDouce(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.lock_outline_rounded, color: camelColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: masque,
                  onChanged: onChanged,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                        ValidateurMotDePasse.maxLongueur)
                  ],
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.couleurTexte(context)),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                        color: AppTheme.couleurTexteAttenue(context),
                        fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  masque
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: camelColor,
                  size: 20,
                ),
                onPressed: onToggleMasque,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistSecurite(String text) {
    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, top: 2),
        child: Text(
          ValidateurMotDePasse.aideExigences,
          style:
              TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context), height: 1.3),
        ),
      );
    }

    final longOk = ValidateurMotDePasse.aLongueurValide(text);
    final majOk = ValidateurMotDePasse.aMajuscule(text);
    final minOk = ValidateurMotDePasse.aMinuscule(text);
    final chifOk = ValidateurMotDePasse.aChiffre(text);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppTheme.couleurSurfaceDouce(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _critereLigne(longOk, "Au moins 8 caractères (max 64)"),
          const SizedBox(height: 3),
          _critereLigne(majOk, "Au moins 1 majuscule (A-Z)"),
          const SizedBox(height: 3),
          _critereLigne(minOk, "Au moins 1 minuscule (a-z)"),
          const SizedBox(height: 3),
          _critereLigne(chifOk, "Au moins 1 chiffre (0-9)"),
        ],
      ),
    );
  }

  Widget _critereLigne(bool valide, String texte) {
    return Row(
      children: [
        Icon(
          valide
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: valide ? AppTheme.oliveProfond : AppTheme.textePale,
        ),
        const SizedBox(width: 6),
        Text(
          texte,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: valide ? FontWeight.w700 : FontWeight.w500,
            color: valide ? AppTheme.oliveProfond : AppTheme.couleurTexteAttenue(context),
          ),
        ),
      ],
    );
  }
}
