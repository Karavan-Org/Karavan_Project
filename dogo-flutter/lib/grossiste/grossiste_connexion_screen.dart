import 'package:flutter/material.dart';
import '../widgets/bouton_bascule_theme.dart';
import '../widgets/mot_de_passe_oublie_modal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/validateur_mot_de_passe.dart';
import '../widgets/bouton_auth0_signin.dart';
import '../models/role_acteur.dart';
import '../theme/app_theme.dart';
import 'grossiste_acces.dart';
import 'grossiste_inscription_screen.dart';
import 'grossiste_onboarding_widgets.dart';

/// Connexion du Grossiste (maquette Figma « CONNEXION »)
class GrossisteConnexionScreen extends StatefulWidget {
  const GrossisteConnexionScreen({super.key});

  @override
  State<GrossisteConnexionScreen> createState() =>
      _GrossisteConnexionScreenState();
}

class _GrossisteConnexionScreenState extends State<GrossisteConnexionScreen> {
  final _telephoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _pinMasque = true;
  bool _seSouvenir = true;
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    _telephoneController.addListener(_masquerNotification);
    _pinController.addListener(_masquerNotification);
  }

  void _masquerNotification() {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  @override
  void dispose() {
    _telephoneController.removeListener(_masquerNotification);
    _pinController.removeListener(_masquerNotification);
    _telephoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final telephone = _telephoneController.text.trim();
    final motDePasse = _pinController.text.trim();
    if (telephone.length < 8) {
      afficherErreur(
          context, "Veuillez renseigner un numéro de téléphone valide");
      return;
    }
    final erreurMdp = ValidateurMotDePasse.validerConnexion(motDePasse);
    if (erreurMdp != null) {
      afficherErreur(context, erreurMdp);
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
        await AuthService.instance.deconnecter();
        throw const ApiException(
            statusCode: 403,
            message: "Ce numéro n'est pas celui d'un compte Grossiste");
      }
      final destination = await ecranGrossisteSelonDossier(profil);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;

      final estCompteInexistant = e is ApiException &&
          (e.code == 'COMPTE_INEXISTANT' ||
              e.statusCode == 404 ||
              e.message.toLowerCase().contains('aucun compte'));

      if (estCompteInexistant) {
        _proposerInscriptionGrossiste(telephone);
        return;
      }

      // Procédure standard pour compte existant mais mot de passe / code erroné
      _pinController.clear();
      final String message;
      if (e is ApiException && e.statusCode == 401) {
        message = 'Mot de passe ou code secret incorrect. Veuillez vérifier votre saisie et réessayer.';
      } else if (e is ApiException && e.statusCode == 423) {
        message = e.message;
      } else if (e is ApiException) {
        message = e.messageComplet;
      } else {
        message = 'Impossible de se connecter au serveur Karavan. Veuillez vérifier votre connexion internet et réessayer.';
      }
      afficherErreur(context, message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _proposerInscriptionGrossiste(String telephone) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = AppTheme.estSombre(ctx);
        const camelColor = AppTheme.bissap;
        return AlertDialog(
          backgroundColor: AppTheme.couleurCarte(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Compte grossiste introuvable",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Aucun compte grossiste Karavan n'est associé au numéro :",
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.couleurTexte(ctx),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_rounded, size: 16, color: camelColor),
                    const SizedBox(width: 8),
                    Text(
                      telephone,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Vous souhaitez proposer vos stocks sur Karavan ? Inscrivez votre entreprise grossiste pour démarrer.",
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.couleurTexteAttenue(ctx),
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Corriger le numéro",
                style: TextStyle(
                  color: AppTheme.couleurTexteAttenue(ctx),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrossisteInscriptionScreen(
                      initialTelephone: telephone,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text(
                "S'inscrire comme grossiste",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: camelColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }

  void _pinOublie() {
    MotDePasseOublieModal.ouvrir(
      context,
      initialTelephone: _telephoneController.text.trim(),
      onMotDePasseReinitialise: (tel) {
        setState(() {
          _telephoneController.text = tel;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      body: Stack(
        children: [
          // Motif de carte du monde en filigrane
          Positioned(
            top: 75,
            left: 12,
            right: 8,
            child: IgnorePointer(
              child: Opacity(opacity: AppTheme.estSombre(context) ? 0.12 : 0.85, child: SvgPicture.asset('assets/images/grossiste/connexion_watermark.svg', fit: BoxFit.fill, height: 266)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        padding: const EdgeInsets.only(top: 12),
                        icon: const Icon(Icons.arrow_back,
                            color: AppTheme.primary, size: 30),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: BoutonBasculeTheme(compact: true),
                      ),
                    ],
                  ),
                  Image.asset('assets/images/logo_karavan.png',
                      height: 72, fit: BoxFit.contain),
                  const SizedBox(height: 18),
                  Text(
                    "Bienvenue Grossiste !",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppTheme.policeTitre, 
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.couleurTexte(context)),
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
                    couleurIndice: AppTheme.couleurTexteAttenue(context),
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
                    couleurIndice: AppTheme.couleurTexteAttenue(context),
                    hauteur: 56,
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
                            color:
                                _seSouvenir ? AppTheme.primary : AppTheme.couleurCarte(context),
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: AppTheme.primary, width: 1.4),
                          ),
                          child: _seSouvenir
                              ? const Icon(Icons.check,
                                  size: 15, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text("Se souvenir de moi", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  BoutonArrivee(
                      libelle: "Se connecter",
                      chargement: _chargement,
                      onPressed: _seConnecter),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: _pinOublie,
                    child: const Text(
                      "Mot de passe oublié ?",
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Séparateur OU
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.couleurBordure(context), thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          "OU",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.couleurTexteAttenue(context),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.couleurBordure(context), thickness: 1)),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Continuer avec Auth0 (rôle grossiste avec confirmation 2FA)
                  const BoutonAuth0SignIn(role: RoleActeur.grossiste),

                  const SizedBox(height: 36),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const GrossisteInscriptionScreen()),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style:
                            const TextStyle(fontSize: 13.5, color: AppTheme.primary),
                        children: [
                          TextSpan(text: "Pas encore de compte ? ", style: TextStyle(color: AppTheme.couleurTexteAttenue(context))),
                          const TextSpan(
                              text: " | ",
                              style: TextStyle(color: AppTheme.bordureForte)),
                          const TextSpan(
                            text: "S'inscrire",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline),
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
