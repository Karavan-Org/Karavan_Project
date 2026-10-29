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
            // Repli gracieux : affichage de l'emoji drapeau ou du code ISO
            return fallback ??
                Container(
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
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: AppTheme.couleurSurfaceDouce(context),
              alignment: Alignment.center,
            );
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
        children: [
          DrapeauPays(
            pays: info.codeIso,
            largeur: compact ? 16 : 20,
            hauteur: compact ? 11 : 14,
          ),
          const SizedBox(width: 5),
          Text(
            info.nomFr,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.couleurTexte(context),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              info.codeIso,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.couleurTexteAttenue(context),
              ),
            ),
          ],
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

