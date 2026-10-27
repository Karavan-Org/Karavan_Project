import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../commercant/commercant_otp_screen.dart';

/// Bouton officiel « Continuer avec Google » respectant la charte graphique Google et l'identité visuelle Karavan.
class BoutonGoogleSignIn extends StatelessWidget {
  final RoleActeur role;
  final String libelle;
  final VoidCallback? onAvantClic;
  final ValueChanged<String>? onTelephoneConfirme;

  const BoutonGoogleSignIn({
    super.key,
    required this.role,
    this.libelle = "Continuer avec Google",
    this.onAvantClic,
    this.onTelephoneConfirme,
  });

  @override
  Widget build(BuildContext context) {
    final estSombre = AppTheme.estSombre(context);
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);

    return InkWell(
      onTap: () {
        if (onAvantClic != null) onAvantClic!();
        GoogleAuthModal.ouvrir(context: context, role: role);
      },
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
            const GoogleGIcon(taille: 22),
            const SizedBox(width: 12),
            Text(
              libelle,
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

/// Logo vectoriel officiel Google « G » 4 couleurs (Bleu, Rouge, Jaune, Vert)
class GoogleGIcon extends StatelessWidget {
  final double taille;

  const GoogleGIcon({super.key, this.taille = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: CustomPaint(
        painter: _GoogleGLogoPainter(),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centre = Offset(w / 2, h / 2);
    final rayonExt = w * 0.48;
    final epaisseur = w * 0.22;
    final rect = Rect.fromCircle(center: centre, radius: rayonExt);

    final paintBleu = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    final paintRouge = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    final paintJaune = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    final paintVert = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    // Arcs formant le cercle Google
    // Bleu : quart supérieur droit et barre horizontale
    canvas.drawArc(rect, -0.6, 1.2, false, paintBleu);
    // Vert : quart inférieur
    canvas.drawArc(rect, 0.6, 1.2, false, paintVert);
    // Jaune : quart inférieur gauche
    canvas.drawArc(rect, 1.8, 1.2, false, paintJaune);
    // Rouge : quart supérieur
    canvas.drawArc(rect, 3.0, 1.2, false, paintRouge);

    // Barre transversale bleue du "G"
    final paintBarre = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final rectBarre = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.44, h * 0.40, w * 0.50, h * 0.20),
      const Radius.circular(2),
    );
    canvas.drawRRect(rectBarre, paintBarre);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Modal moderne d'authentification Google avec confirmation obligatoire du numéro 2FA
class GoogleAuthModal extends StatefulWidget {
  final RoleActeur role;

  const GoogleAuthModal({super.key, required this.role});

  static Future<void> ouvrir({
    required BuildContext context,
    required RoleActeur role,
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
            child: GoogleAuthModal(role: role),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoogleAuthModal(role: role),
    );
  }

  @override
  State<GoogleAuthModal> createState() => _GoogleAuthModalState();
}

class _GoogleAuthModalState extends State<GoogleAuthModal> {
  // Compte Google connecté par défaut dans le navigateur ou personnalisable
  final String _nomGoogle = "Salif Modibo Keïta";
  final String _emailGoogle = "salifmodibok@gmail.com";
  final TextEditingController _phoneController = TextEditingController(text: "+223 ");
  bool _envoiEnCours = false;
  String? _messageErreur;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _libelleRole(RoleActeur role) {
    switch (role) {
      case RoleActeur.commercant:
        return "Commerçant";
      case RoleActeur.courtier:
        return "Courtier";
      case RoleActeur.grossiste:
        return "Grossiste";
    }
  }

  /// Génère un secret aléatoire fort conforme à RG-07 pour sécuriser le compte Google
  String _genererSecretSecurise() {
    final rng = math.Random.secure();
    const lettresMaj = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    const lettresMin = "abcdefghijkmnopqrstuvwxyz";
    const chiffres = "23456789";
    const symboles = "!@#\$%*=";
    const tous = lettresMaj + lettresMin + chiffres + symboles;

    final chars = <String>[
      lettresMaj[rng.nextInt(lettresMaj.length)],
      lettresMin[rng.nextInt(lettresMin.length)],
      chiffres[rng.nextInt(chiffres.length)],
      symboles[rng.nextInt(symboles.length)],
    ];
    for (int i = 0; i < 20; i++) {
      chars.add(tous[rng.nextInt(tous.length)]);
    }
    chars.shuffle(rng);
    return chars.join();
  }

  Future<void> _confirmerEtRecevoir2FA() async {
    final telBrut = _phoneController.text.trim();
    final telNettoye = telBrut.replaceAll(RegExp(r'\s+'), '');

    if (telNettoye.length < 8) {
      setState(() {
        _messageErreur = "Veuillez saisir un numéro de téléphone valide pour recevoir le code 2FA.";
      });
      return;
    }

    setState(() {
      _envoiEnCours = true;
      _messageErreur = null;
    });

    try {
      String? codeOtpSimule;
      final secretCompte = _genererSecretSecurise();

      // Inscription ou renvoi OTP selon l'existence du compte
      try {
        final res = await AuthService.instance.inscrire(
          typeActeur: widget.role.name.toUpperCase(),
          telephone: telNettoye,
          nom: _nomGoogle,
          motDePasse: secretCompte,
          pin: secretCompte,
          nomBoutique: widget.role == RoleActeur.commercant ? "Boutique $_nomGoogle" : null,
          quartierBamako: widget.role == RoleActeur.commercant ? "Grand Marché" : null,
          nomBoutiqueMarche: widget.role == RoleActeur.grossiste ? "Établissements $_nomGoogle" : null,
          numeroNif: widget.role == RoleActeur.grossiste ? "084729103M" : null,
          nomSocieteImport: widget.role == RoleActeur.courtier ? "Transit & Fret $_nomGoogle" : null,
          licenceTransit: widget.role == RoleActeur.courtier ? "LT-BKO-2026" : null,
        );
        codeOtpSimule = res['codeOtp']?.toString();
      } on ApiException catch (e) {
        if (e.statusCode == 409 || e.code == 'CONFLIT') {
          setState(() {
            _envoiEnCours = false;
            _messageErreur =
                "Ce numéro de téléphone est déjà associé à un compte existant. Veuillez vous connecter directement avec votre mot de passe.";
          });
          return;
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(); // Fermer la modale Google

      // Redirection immédiate vers l'écran de vérification 2FA OTP
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommercantOtpScreen(
            numeroTelephone: telNettoye,
            role: widget.role,
            codeSimulation: codeOtpSimule,
            nom: _nomGoogle,
            motDePasse: secretCompte,
            pin: secretCompte,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoiEnCours = false;
        _messageErreur = e is ApiException
            ? e.messageComplet
            : "Une erreur est survenue lors de l'envoi du code 2FA : $e";
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
                width: 42,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: couleurBordure,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // En-tête Google & Karavan
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: estSombre ? Colors.black26 : const Color(0xFFF1F3F4),
                    shape: BoxShape.circle,
                    border: Border.all(color: couleurBordure),
                  ),
                  child: const Center(child: GoogleGIcon(taille: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Connexion avec Google",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: couleurTexte,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Espace ${_libelleRole(widget.role)} Karavan",
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.doreKaravan,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: couleurAttenue),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Carte Compte Google actif sur le navigateur
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: estSombre ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: couleurBordure, width: 1.1),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF4285F4),
                    child: Text(
                      _nomGoogle.isNotEmpty ? _nomGoogle[0] : "G",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _nomGoogle,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: couleurTexte,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF34A853), size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _emailGoogle,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: couleurAttenue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34A853).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Navigateur",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Encart informatif 2FA Mali & Logistique
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.doreKaravan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.doreKaravan.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppTheme.doreKaravan, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Double Authentification obligatoire (2FA)",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: couleurTexte,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Google ne transmet pas de numéro malien vérifié. Pour sécuriser vos achats groupés, vos retraits au dépôt et vos transactions Mobile Money (Orange Money, Wave, Moov), veuillez confirmer votre numéro.",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: couleurAttenue,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Champ de confirmation du numéro de téléphone
            Text(
              "Numéro de téléphone Malien (+223)",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: couleurTexte,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: couleurCarte,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _messageErreur != null ? AppTheme.danger : couleurBordure,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.bissap.withValues(alpha: 0.08),
                    ),
                    child: const Icon(Icons.phone_iphone_rounded, color: AppTheme.bissap, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+]')),
                      ],
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: couleurTexte,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: "+223 70 00 00 00",
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: couleurAttenue,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_messageErreur != null) ...[
              const SizedBox(height: 8),
              Text(
                _messageErreur!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.danger,
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Bouton de confirmation & envoi 2FA
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _envoiEnCours ? null : _confirmerEtRecevoir2FA,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bissap,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _envoiEnCours
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sms_rounded, size: 19),
                          SizedBox(width: 10),
                          Text(
                            "Confirmer et recevoir le code 2FA",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                "Étape suivante : Vérification OTP SMS puis dépôt des documents KYC",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: couleurAttenue,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
