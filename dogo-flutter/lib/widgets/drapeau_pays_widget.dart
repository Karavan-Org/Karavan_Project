import 'package:flutter/material.dart';
import '../services/pays_resolver_service.dart';
import '../theme/app_theme.dart';

/// Widget universel d'affichage d'un drapeau de pays avec résolution automatique.
/// Reconnaît n'importe quelle entrée (nom en français, nom en anglais, code ISO 2 ou 3 lettres)
/// et affiche un drapeau visuel net, propre, avec coins arrondis et bordure douce.
class DrapeauPays extends StatelessWidget {
  final String? pays;
  final double largeur;
  final double hauteur;
  final double rayon;
  final bool avecNom;
  final bool avecCode;
  final TextStyle? styleTexte;
  final Widget? fallback;

  const DrapeauPays({
    super.key,
    required this.pays,
    this.largeur = 22.0,
    this.hauteur = 15.0,
    this.rayon = 3.5,
    this.avecNom = false,
    this.avecCode = false,
    this.styleTexte,
    this.fallback,
  });

  Widget _construireRepliCouleurs(BuildContext context, PaysInfo info) {
    final code = info.codeIso.toUpperCase();
    switch (code) {
      case 'ML':
        return const Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFF14B53A))),
            Expanded(child: ColoredBox(color: Color(0xFFFCD116))),
            Expanded(child: ColoredBox(color: Color(0xFFCE1126))),
          ],
        );
      case 'CI':
        return const Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFFF77F00))),
            Expanded(child: ColoredBox(color: Color(0xFFFFFFFF))),
            Expanded(child: ColoredBox(color: Color(0xFF009A44))),
          ],
        );
      case 'FR':
        return const Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFF002654))),
            Expanded(child: ColoredBox(color: Color(0xFFFFFFFF))),
            Expanded(child: ColoredBox(color: Color(0xFFCE1126))),
          ],
        );
      case 'GN':
        return const Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFFCE1126))),
            Expanded(child: ColoredBox(color: Color(0xFFFCD116))),
            Expanded(child: ColoredBox(color: Color(0xFF009460))),
          ],
        );
      case 'NG':
        return const Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFF008751))),
            Expanded(child: ColoredBox(color: Color(0xFFFFFFFF))),
            Expanded(child: ColoredBox(color: Color(0xFF008751))),
          ],
        );
      case 'GH':
        return const Column(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFFCE1126))),
            Expanded(child: ColoredBox(color: Color(0xFFFCD116))),
            Expanded(child: ColoredBox(color: Color(0xFF006B3F))),
          ],
        );
      case 'SN':
        return const Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFF00853F))),
            Expanded(child: ColoredBox(color: Color(0xFFFDEF42))),
            Expanded(child: ColoredBox(color: Color(0xFFE31B23))),
          ],
        );
      case 'TR':
        return Container(
          color: const Color(0xFFE30A17),
          alignment: Alignment.center,
          child: const Text('🇹🇷', style: TextStyle(fontSize: 10)),
        );
      case 'CN':
        return Container(
          color: const Color(0xFFDE2910),
          alignment: Alignment.center,
          child: const Text('★', style: TextStyle(color: Color(0xFFFFDE00), fontSize: 10, fontWeight: FontWeight.bold)),
        );
      case 'MA':
        return Container(
          color: const Color(0xFFC1272D),
          alignment: Alignment.center,
          child: const Text('★', style: TextStyle(color: Color(0xFF006233), fontSize: 10, fontWeight: FontWeight.bold)),
        );
      case 'BR':
        return Container(
          color: const Color(0xFF009739),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFEDD00),
              shape: BoxShape.circle,
            ),
          ),
        );
      default:
        return Container(
          color: AppTheme.couleurSurfaceDouce(context),
          alignment: Alignment.center,
          child: Text(
            info.codeIso,
            style: TextStyle(
              fontSize: (hauteur * 0.55).clamp(8.0, 13.0),
              fontWeight: FontWeight.w800,
              color: AppTheme.couleurTexte(context),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = PaysResolverService.instance.resoudre(pays);

    final widgetDrapeau = Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(
          color: AppTheme.estSombre(context)
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.12),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rayon - 0.5),
        child: Image.network(
          info.urlDrapeau(largeur: largeur > 30 ? 80 : 40),
          width: largeur,
          height: hauteur,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return fallback ?? _construireRepliCouleurs(context, info);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _construireRepliCouleurs(context, info);
          },
        ),
      ),
    );

    if (!avecNom && !avecCode) {
      return widgetDrapeau;
    }

    final texteNom = avecNom
        ? (avecCode ? "${info.nomFr} (${info.codeIso})" : info.nomFr)
        : "(${info.codeIso})";

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        widgetDrapeau,
        const SizedBox(width: 6),
        Text(
          texteNom,
          style: styleTexte ??
              TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.couleurTexte(context),
              ),
        ),
      ],
    );
  }
}

/// Badge pilule élégant combinant le drapeau et le nom du pays d'origine
class DrapeauBadge extends StatelessWidget {
  final String? pays;
  final bool compact;
  final VoidCallback? onTap;

  const DrapeauBadge({
    super.key,
    required this.pays,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = PaysResolverService.instance.resoudre(pays);

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.couleurSurfaceDouce(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.couleurBordure(context),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DrapeauPays(
            pays: info.codeIso,
            largeur: compact ? 18 : 22,
            hauteur: compact ? 12 : 15,
            rayon: 3,
          ),
          const SizedBox(width: 6),
          Text(
            info.nomFr,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.couleurTexte(context),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    return content;
  }
}
