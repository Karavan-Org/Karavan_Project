import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Couleurs des écrans d'arrivée du Grossiste (maquettes Figma « CONNEXION », « inscription »,
/// « Soumettre mes documents », « Espace Vendeur »)
class CouleursArrivee {
  CouleursArrivee._();

  static const Color fond = Color(0xFFF9F7F4);
  static const Color titre = Color(0xFF2D231C);
  static const Color titreConnexion = Color(0xFF0A1838);
  static const Color texteDoux = Color(0xFF7C6E65);
  static const Color indice = Color(0xFF9C8E84);
  static const Color bordure = Color(0xFFE8DED5);
  static const Color bordureConnexion = Color(0xFFB98F72);
  static const Color creme = Color(0xFFF5E8D3);
  static const Color vert = Color(0xFF10B981);
  static const Color ambre = Color(0xFFEEA823);
  static const Color ambreFonce = Color(0xFFB45309);
}

/// Champ blanc arrondi avec icône à gauche ; un astérisque camel marque les champs obligatoires.
class ChampArrivee extends StatelessWidget {
  final IconData icone;
  final String indice;
  final bool obligatoire;
  final TextEditingController controller;
  final TextInputType clavier;
  final List<TextInputFormatter>? formateurs;
  final bool masque;
  final Widget? suffixe;
  final Color couleurBordure;
  final Color couleurIndice;
  final double hauteur;

  const ChampArrivee({
    super.key,
    required this.icone,
    required this.indice,
    required this.controller,
    this.obligatoire = false,
    this.clavier = TextInputType.text,
    this.formateurs,
    this.masque = false,
    this.suffixe,
    this.couleurBordure = CouleursArrivee.bordure,
    this.couleurIndice = CouleursArrivee.indice,
    this.hauteur = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: hauteur,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleurBordure, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icone, size: 19, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: clavier,
              inputFormatters: formateurs,
              obscureText: masque,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CouleursArrivee.titre),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hint: Text.rich(
                  TextSpan(
                    text: indice,
                    style: TextStyle(fontSize: 13.5, color: couleurIndice),
                    children: [
                      if (obligatoire)
                        const TextSpan(text: ' *', style: TextStyle(color: AppTheme.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (suffixe != null) suffixe!,
        ],
      ),
    );
  }
}

/// Bouton principal en dégradé camel, pleine largeur
class BoutonArrivee extends StatelessWidget {
  final String libelle;
  final VoidCallback? onPressed;
  final bool chargement;

  const BoutonArrivee({super.key, required this.libelle, this.onPressed, this.chargement = false});

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null && !chargement;
    return Opacity(
      opacity: actif || chargement ? 1 : 0.6,
      child: Material(
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: 54,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFB68A6A), Color(0xFFA67954)]),
          ),
          child: InkWell(
            onTap: actif ? onPressed : null,
            child: Center(
              child: chargement
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                    )
                  : Text(
                      libelle,
                      style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordure en pointillés (zone « Ajouter un document »)
class BordurePointillee extends CustomPainter {
  final Color couleur;
  final double rayon;

  const BordurePointillee({this.couleur = AppTheme.primary, this.rayon = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final pinceau = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final chemin = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(rayon)));
    for (final mesure in chemin.computeMetrics()) {
      for (double d = 0; d < mesure.length; d += 9) {
        canvas.drawPath(mesure.extractPath(d, d + 5), pinceau);
      }
    }
  }

  @override
  bool shouldRepaint(BordurePointillee old) => old.couleur != couleur || old.rayon != rayon;
}

void afficherErreur(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFC0392B),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}
