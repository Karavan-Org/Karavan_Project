import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'grossiste_acces.dart';
import 'grossiste_inscription_screen.dart';
import 'grossiste_onboarding_widgets.dart';

/// Connexion du Grossiste (maquette Figma « CONNEXION »)
class GrossisteConnexionScreen extends StatefulWidget {
  const GrossisteConnexionScreen({super.key});

  @override
  State<GrossisteConnexionScreen> createState() => _GrossisteConnexionScreenState();
}

class _GrossisteConnexionScreenState extends State<GrossisteConnexionScreen> {
  final _telephoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _pinMasque = true;
  bool _seSouvenir = true;
  bool _chargement = false;

  @override
  void dispose() {
    _telephoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final telephone = _telephoneController.text.trim();
    final motDePasse = _pinController.text.trim();
    if (telephone.length < 8) {
      afficherErreur(context, "Veuillez renseigner un numéro de téléphone valide");
      return;
    }
    if (motDePasse.length < 8) {
      afficherErreur(context, "Le mot de passe doit comporter au moins 8 caractères");
      return;
    }

    setState(() => _chargement = true);
    try {
      final profil = await AuthService.instance.connecter(
        telephone: telephone,
        motDePasse: motDePasse,
        pin: motDePasse,
      );
      if (profil.type != 'GROSSISTE') {
        AuthService.instance.deconnecter();
        throw const ApiException(statusCode: 403, message: "Ce numéro n'est pas celui d'un compte Grossiste");
      }
      final destination = await ecranGrossisteSelonDossier(profil);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      afficherErreur(context, e is ApiException ? e.messageComplet : 'Erreur de connexion : $e');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _pinOublie() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Mot de passe oublié"),
        content: const Text(
          "Pour des raisons de sécurité, la réinitialisation du mot de passe se fait avec l'équipe d'intégration dɔgɔ. "
          "Contactez le support depuis votre agence ou par WhatsApp à Bamako.",
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Compris"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursArrivee.fond,
      body: Stack(
        children: [
          // Motif de carte du monde en filigrane
          Positioned(
            top: 75,
            left: 12,
            right: 8,
            child: IgnorePointer(
              child: SvgPicture.asset('assets/images/grossiste/connexion_watermark.svg', fit: BoxFit.fill, height: 266),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      padding: const EdgeInsets.only(top: 12),
                      icon: const Icon(Icons.arrow_back, color: AppTheme.primary, size: 30),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Image.asset('assets/images/logo_dogo.png', height: 72, fit: BoxFit.contain),
                  const SizedBox(height: 18),
                  const Text(
                    "Bienvenue Grossiste !",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CouleursArrivee.titreConnexion),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Connectez-vous à votre espace",
                    style: TextStyle(fontSize: 14.5, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 54),
                  ChampArrivee(
                    icone: Icons.lock_outline,
                    indice: "Numéro de téléphone",
                    controller: _telephoneController,
                    clavier: TextInputType.phone,
                    couleurBordure: CouleursArrivee.bordureConnexion,
                    couleurIndice: const Color(0xFF64748B),
                    hauteur: 56,
                  ),
                  const SizedBox(height: 16),
                  ChampArrivee(
                    icone: Icons.lock_outline,
                    indice: "Mot de passe",
                    controller: _pinController,
                    clavier: TextInputType.visiblePassword,
                    formateurs: [LengthLimitingTextInputFormatter(64)],
                    masque: _pinMasque,
                    couleurBordure: CouleursArrivee.bordureConnexion,
                    couleurIndice: AppTheme.primary,
                    hauteur: 56,
                    suffixe: IconButton(
                      icon: Icon(
                        _pinMasque ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _pinMasque = !_pinMasque),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => setState(() => _seSouvenir = !_seSouvenir),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _seSouvenir ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.primary, width: 1.4),
                          ),
                          child: _seSouvenir ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Se souvenir de moi",
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  BoutonArrivee(libelle: "Se connecter", chargement: _chargement, onPressed: _seConnecter),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: _pinOublie,
                    child: const Text(
                      "Mot de passe oublié ?",
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 84),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GrossisteInscriptionScreen()),
                    ),
                    child: const Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 13.5, color: AppTheme.primary),
                        children: [
                          TextSpan(text: "Pas encore de compte ? "),
                          TextSpan(text: " | ", style: TextStyle(color: Color(0xFFCBD5E1))),
                          TextSpan(
                            text: "S'inscrire",
                            style: TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
