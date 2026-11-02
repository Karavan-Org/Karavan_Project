import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../grossiste/grossiste_acces.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/session_storage_service.dart';
import '../services/validateur_mot_de_passe.dart';
import '../theme/app_theme.dart';
import '../widgets/bouton_bascule_theme.dart';
import '../widgets/bouton_google_signin.dart';
import '../widgets/champ_telephone_international.dart';
import '../widgets/mot_de_passe_oublie_modal.dart';
import 'courtier_inscription_screen.dart';

/// Écran de Connexion dédié exclusivement au Courtier (Transit, Groupage & Retraits).
/// Totalement isolé des espaces Commerçant et Grossiste après le choix initial.
class CourtierConnexionScreen extends StatefulWidget {
  const CourtierConnexionScreen({super.key});

  @override
  State<CourtierConnexionScreen> createState() => _CourtierConnexionScreenState();
}

class _CourtierConnexionScreenState extends State<CourtierConnexionScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  String _telephoneComplet = '';
  bool _obscurePin = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    GoogleSignInService.instance.definirContexteEnCours(
      role: RoleActeur.courtier,
      estInscription: false,
    );
    SessionStorageService.instance.sauvegarderDernierEspace('courtier');
    _phoneController.addListener(_masquerNotification);
    _pinController.addListener(_masquerNotification);
  }

  void _masquerNotification() {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_masquerNotification);
    _pinController.removeListener(_masquerNotification);
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final localPhone = _phoneController.text.trim();
    final phone = _telephoneComplet.isNotEmpty ? _telephoneComplet : localPhone;
    final pin = _pinController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Veuillez renseigner votre numéro de téléphone"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final erreurMdp = ValidateurMotDePasse.validerConnexion(pin);
    if (erreurMdp != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erreurMdp),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profil = await AuthService.instance.connecter(
        telephone: phone,
        motDePasse: pin,
        typeActeur: RoleActeur.courtier.codeBackend,
      );
      if (!mounted) return;

      if (profil.roleActeur != RoleActeur.courtier) {
        await AuthService.instance.deconnecter();
        throw ApiException(
          statusCode: 403,
          message:
              "Ce numéro est enregistré dans l'espace ${profil.roleActeur.libelle} et ne peut pas être utilisé dans l'espace Courtier.",
        );
      }

      final destination = await ecranSelonStatut(profil, RoleActeur.courtier);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final estCompteInexistant = e is ApiException &&
          (e.code == 'COMPTE_INEXISTANT' ||
              e.statusCode == 404 ||
              e.message.toLowerCase().contains('aucun compte'));

      if (estCompteInexistant) {
        _proposerInscriptionCourtier(phone);
        return;
      }

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _proposerInscriptionCourtier(String telephone) {
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
                  Icons.local_shipping_rounded,
                  color: AppTheme.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Compte courtier introuvable",
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
                "Aucun compte courtier Karavan n'est associé au numéro :",
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
                "Vous êtes transitaire ou commissionnaire agréé ? Créez votre compte courtier pour organiser vos convois et points de retrait.",
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
                    builder: (_) => CourtierInscriptionScreen(
                      initialTelephone: telephone,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text(
                "S'inscrire comme courtier",
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

  @override
  Widget build(BuildContext context) {
    const camelColor = AppTheme.bissap;
    const borderColor = AppTheme.bordureForte;

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: camelColor, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: const [
          BoutonBasculeTheme(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Image.asset(
                'assets/images/logo_karavan.png',
                height: 64,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              Text(
                "Bienvenue Courtier !",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.policeTitre,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexte(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: camelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_rounded, size: 15, color: camelColor),
                    SizedBox(width: 6),
                    Text(
                      "Espace Courtier • Transit & Groupage",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: camelColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              // CHAMP TÉLÉPHONE INTERNATIONAL AVEC INDICATIFS PAYS (intl_phone_field)
              ChampTelephoneInternational(
                controller: _phoneController,
                label: "Téléphone professionnel",
                borderColor: borderColor,
                accentColor: camelColor,
                onNumeroCompletChange: (complet) {
                  _telephoneComplet = complet;
                },
              ),
              const SizedBox(height: 16),
              _buildInputField(
                icon: Icons.lock_outline,
                label: "Mot de passe",
                hint: "Entrez votre mot de passe",
                controller: _pinController,
                obscureText: _obscurePin,
                camelColor: camelColor,
                trailing: IconButton(
                  icon: Icon(
                    _obscurePin
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: camelColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _rememberMe ? camelColor : Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: _rememberMe ? camelColor : borderColor,
                              width: 1.4,
                            ),
                          ),
                          child: _rememberMe
                              ? const Icon(Icons.check, size: 13, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Se souvenir de\nmoi",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.terreDouce,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      MotDePasseOublieModal.ouvrir(
                        context,
                        initialTelephone: _phoneController.text.trim(),
                        role: RoleActeur.courtier,
                        onMotDePasseReinitialise: (tel) {
                          setState(() => _phoneController.text = tel);
                        },
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "Mot de passe oublié ?",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: camelColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _seConnecter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: camelColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.2),
                      )
                    : const Text(
                        "Se connecter",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
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
              const BoutonGoogleSignIn(
                role: RoleActeur.courtier,
                estInscription: false,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Nouveau courtier sur Karavan ? ",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.couleurTexteAttenue(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const CourtierInscriptionScreen(),
                            ),
                          )
                          .then((_) {
                            GoogleSignInService.instance.definirContexteEnCours(
                              role: RoleActeur.courtier,
                              estInscription: false,
                            );
                          });
                    },
                    child: const Text(
                      "Inscription",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: camelColor,
                        decoration: TextDecoration.underline,
                        decorationColor: camelColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required Color camelColor,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? trailing,
  }) {
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: couleurCarte,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: couleurBordure, width: 1.2),
        boxShadow: AppTheme.ombreDouce,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: couleurBordure, width: 1.1),
            ),
            child: Icon(icon, color: camelColor, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: couleurAttenue,
                  ),
                ),
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: couleurTexte,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: couleurAttenue,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}

