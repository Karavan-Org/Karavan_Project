import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../services/google_sign_in_service.dart';
import '../theme/app_theme.dart';
import 'google_button_renderer.dart';

/// Bouton officiel « Continuer avec Google » / « S'inscrire avec Google » compatible Google Sign-In v7+ (Android & Web)
class BoutonGoogleSignIn extends StatefulWidget {
  final RoleActeur role;
  final String libelle;
  final bool estInscription;
  final VoidCallback? onAvantClic;

  const BoutonGoogleSignIn({
    super.key,
    required this.role,
    this.libelle = "Continuer avec Google",
    this.estInscription = false,
    this.onAvantClic,
  });

  @override
  State<BoutonGoogleSignIn> createState() => _BoutonGoogleSignInState();
}

class _BoutonGoogleSignInState extends State<BoutonGoogleSignIn> {
  bool _enChargement = false;

  bool get _modeInscription =>
      widget.estInscription || widget.libelle.toLowerCase().contains("inscri");

  @override
  void initState() {
    super.initState();
    // Préchauffage et initialisation de GoogleSignIn en arrière-plan
    GoogleSignInService.instance.initialiser();
  }

  Future<void> _gererClic(BuildContext context) async {
    if (_enChargement) return;
    if (widget.onAvantClic != null) widget.onAvantClic!();

    setState(() => _enChargement = true);
    try {
      await GoogleSignInService.instance.declencherConnexion(
        context,
        role: widget.role,
        estInscription: _modeInscription,
      );
    } finally {
      if (mounted) setState(() => _enChargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = AppTheme.estSombre(context);
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);

    // Synchroniser le contexte actif (rôle + mode connexion/inscription) lorsque cette route est au premier plan
    if (ModalRoute.of(context)?.isCurrent != false) {
      GoogleSignInService.instance.definirContexteEnCours(
        role: widget.role,
        estInscription: _modeInscription,
      );
    }

    // Sur Flutter Web, Google Identity Services (GIS) fournit le composant sécurisé officiel
    if (kIsWeb) {
      final webButton = buildWebGoogleSignInButton(
        width: 300,
        estSombre: estSombre,
        inscription: _modeInscription,
      );
      if (webButton != null) {
        return Container(
          height: 48,
          alignment: Alignment.center,
          child: webButton,
        );
      }
    }

    // Bouton natif Android / iOS / Desktop conforme à la charte Google Identity
    return InkWell(
      onTap: _enChargement ? null : () => _gererClic(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: couleurCarte,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: estSombre ? couleurBordure : const Color(0xFFDADCE0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: estSombre ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_enChargement)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else
              Image.asset(
                'assets/logo/Google__G__logo.svg.webp',
                width: 22,
                height: 22,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_circle,
                  size: 22,
                  color: Color(0xFF4285F4),
                ),
              ),
            const SizedBox(width: 12),
            Text(
              widget.libelle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: couleurTexte,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
