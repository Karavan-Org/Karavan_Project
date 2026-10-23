import 'package:flutter/material.dart';
import '../widgets/bouton_bascule_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../commercant/commercant_otp_screen.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/validateur_mot_de_passe.dart';
import '../theme/app_theme.dart';
import 'grossiste_onboarding_widgets.dart';

/// Inscription du Grossiste (maquette Figma « inscription »)
class GrossisteInscriptionScreen extends StatefulWidget {
  const GrossisteInscriptionScreen({super.key});

  @override
  State<GrossisteInscriptionScreen> createState() =>
      _GrossisteInscriptionScreenState();
}

class _GrossisteInscriptionScreenState
    extends State<GrossisteInscriptionScreen> {
  final _entrepriseController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _pinMasque = true;
  bool _confirmMasque = true;
  bool _chargement = false;

  @override
  void dispose() {
    _entrepriseController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _creerCompte() async {
    final entreprise = _entrepriseController.text.trim();
    final telephone = _telephoneController.text.trim();
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (entreprise.isEmpty) {
      afficherErreur(context, "Veuillez renseigner le nom de l'entreprise");
      return;
    }
    if (telephone.replaceAll(RegExp(r'\D'), '').length < 8) {
      afficherErreur(
          context, "Veuillez renseigner un numéro de téléphone valide");
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      afficherErreur(context, "L'adresse email n'est pas valide");
      return;
    }
    final erreurMdp = ValidateurMotDePasse.validerCreation(pin);
    if (erreurMdp != null) {
      afficherErreur(context, erreurMdp);
      return;
    }
    final erreurConf = ValidateurMotDePasse.validerConfirmation(pin, confirm);
    if (erreurConf != null) {
      afficherErreur(context, erreurConf);
      return;
    }

    setState(() => _chargement = true);
    try {
      final res = await AuthService.instance.inscrire(
        typeActeur: 'GROSSISTE',
        telephone: telephone,
        nom: entreprise,
        motDePasse: pin,
        pin: pin,
        nomBoutiqueMarche: entreprise,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommercantOtpScreen(
            numeroTelephone: telephone,
            role: RoleActeur.grossiste,
            codeSimulation: res['codeOtp']?.toString(),
            nom: entreprise,
            motDePasse: pin,
            pin: pin,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      afficherErreur(context,
          e is ApiException ? e.messageComplet : "Erreur d'inscription : $e");
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.primary, size: 28),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const BoutonBasculeTheme(compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Image.asset('assets/images/logo_karavan.png',
                  height: 56, fit: BoxFit.contain),
              const SizedBox(height: 14),
              SvgPicture.asset('assets/images/grossiste/port_scene.svg',
                  width: double.infinity, height: 86),
              const SizedBox(height: 8),
              Text(
                "Rejoignez dɔgɔ\nen tant que grossiste",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppTheme.policeTitre, 
                    fontSize: 20.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.couleurTexte(context),
                    height: 1.2),
              ),
              const SizedBox(height: 10),
              Text(
                "Accédez à des milliers de commerçants\net vendez vos produits en toute sécurité.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.couleurTexteAttenue(context),
                    height: 1.4),
              ),
              const SizedBox(height: 18),
              ChampArrivee(
                icone: Icons.store_outlined,
                indice: "Nom de l'entreprise",
                obligatoire: true,
                controller: _entrepriseController,
              ),
              const SizedBox(height: 12),
              ChampArrivee(
                icone: Icons.person_outline,
                indice: "Numéro de téléphone",
                obligatoire: true,
                controller: _telephoneController,
                clavier: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              ChampArrivee(
                icone: Icons.mail_outline,
                indice: "Email (optionnel)",
                controller: _emailController,
                clavier: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              ChampArrivee(
                icone: Icons.lock_outline,
                indice: ValidateurMotDePasse.libelleMotDePasse,
                obligatoire: true,
                controller: _pinController,
                clavier: TextInputType.visiblePassword,
                formateurs: [
                  LengthLimitingTextInputFormatter(
                      ValidateurMotDePasse.maxLongueur)
                ],
                masque: _pinMasque,
                suffixe: IconButton(
                  icon: Icon(
                    _pinMasque
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _pinMasque = !_pinMasque),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ValidateurMotDePasse.aideExigences,
                    style:
                        TextStyle(fontSize: 11, color: CouleursArrivee.indice),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ChampArrivee(
                icone: Icons.lock_outline,
                indice: ValidateurMotDePasse.libelleConfirmation,
                obligatoire: true,
                controller: _confirmPinController,
                clavier: TextInputType.visiblePassword,
                formateurs: [
                  LengthLimitingTextInputFormatter(
                      ValidateurMotDePasse.maxLongueur)
                ],
                masque: _confirmMasque,
                suffixe: IconButton(
                  icon: Icon(
                    _confirmMasque
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _confirmMasque = !_confirmMasque),
                ),
              ),
              const SizedBox(height: 20),
              BoutonArrivee(
                  libelle: "Créer mon compte",
                  chargement: _chargement,
                  onPressed: _creerCompte),
              const SizedBox(height: 26),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
                    children: const [
                      TextSpan(text: "Vous avez déjà un compte ? "),
                      TextSpan(
                        text: "Se connecter",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                          decoration: TextDecoration.underline,
                        ),
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
    );
  }
}
