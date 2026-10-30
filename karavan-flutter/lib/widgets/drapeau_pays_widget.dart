import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import '../services/pays_resolver_service.dart';
import '../theme/app_theme.dart';

/// Drapeau d'un pays (vectoriel, embarqué dans l'application : aucun appel réseau).
/// Accepte un code ISO 2 ou 3 lettres, un nom français ou anglais. Une saisie non reconnue
/// affiche un globe neutre plutôt qu'un drapeau deviné.
class DrapeauPays extends StatelessWidget {
  final String? pays;
  final double largeur;
  final double hauteur;
  final double rayon;
  final bool avecNom;
  final bool avecCode;
  final TextStyle? styleTexte;

  const DrapeauPays({
    super.key,
    required this.pays,
    this.largeur = 22.0,
    this.hauteur = 15.0,
    this.rayon = 2.5,
    this.avecNom = false,
    this.avecCode = false,
    this.styleTexte,
  });

  @override
  Widget build(BuildContext context) {
    final info = PaysResolverService.instance.resoudre(pays);

    final drapeau = Container(
      width: largeur,
      height: hauteur,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(
          color: AppTheme.estSombre(context)
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.10),
          width: 0.6,
        ),
      ),
      decoration: BoxDecoration(
        color: AppTheme.couleurSurfaceDouce(context),
        borderRadius: BorderRadius.circular(rayon),
      ),
      clipBehavior: Clip.antiAlias,
      child: info.estReconnu
          ? CountryFlag.fromCountryCode(
              info.codeIso,
              theme: ImageTheme(width: largeur, height: hauteur),
            )
          : Icon(
              Icons.public,
              size: hauteur * 0.8,
              color: AppTheme.couleurTexteAttenue(context),
            ),
    );

    if (!avecNom && !avecCode) return drapeau;

    final texte = !info.estReconnu
        ? info.nomFr
        : avecNom
            ? (avecCode ? '${info.nomFr} (${info.codeIso})' : info.nomFr)
            : info.codeIso;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        drapeau,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texte,
            overflow: TextOverflow.ellipsis,
            style: styleTexte ??
                TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.couleurTexte(context),
                ),
          ),
        ),
      ],
    );
  }
}

/// Pastille « drapeau + nom du pays d'origine ». Ne s'affiche pas si l'origine n'est pas renseignée.
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
    if (pays == null || pays!.trim().isEmpty) return const SizedBox.shrink();
    final info = PaysResolverService.instance.resoudre(pays);

    final contenu = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.couleurSurfaceDouce(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.couleurBordure(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DrapeauPays(
            pays: pays,
            largeur: compact ? 16 : 20,
            hauteur: compact ? 12 : 15,
          ),
          SizedBox(width: compact ? 5 : 6),
          Flexible(
            child: Text(
              info.nomFr,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.couleurTexte(context),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return contenu;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: contenu,
    );
  }
}
