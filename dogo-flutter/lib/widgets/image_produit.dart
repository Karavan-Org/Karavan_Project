import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api/api_config.dart';
import '../theme/app_theme.dart';

/// Photo d'un produit : photo servie par le backend (/api/public/images/...) ou asset local.
/// Même signature qu'Image.asset ; un chemin vide affiche directement [errorBuilder].
///
/// Les photos des grossistes peuvent atteindre 2000 px : elles sont décodées à la taille
/// d'affichage (× densité de l'écran) plutôt qu'en pleine résolution, ce qui divise la
/// mémoire et le temps de décodage des listes de cartes sans perte visible.
Widget imageProduit(
  String chemin, {
  BoxFit? fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final repli = errorBuilder ??
      (_, __, ___) => const Center(child: Icon(Icons.inventory_2_outlined, color: AppTheme.bissap));
  if (chemin.isEmpty) {
    return Builder(builder: (context) => SizedBox(width: width, height: height, child: repli(context, '', null)));
  }
  final reseau = chemin.startsWith('http://') || chemin.startsWith('https://') || chemin.startsWith('/');
  return LayoutBuilder(
    builder: (context, contraintes) {
      final largeurDecodage = _largeurDecodage(
        context,
        largeur: width ?? (contraintes.hasBoundedWidth ? contraintes.maxWidth : null),
        hauteur: height ?? (contraintes.hasBoundedHeight ? contraintes.maxHeight : null),
      );
      if (reseau) {
        return Image.network(
          ApiConfig.resolutionImageUrl(chemin),
          fit: fit,
          width: width,
          height: height,
          cacheWidth: largeurDecodage,
          errorBuilder: repli,
        );
      }
      return Image.asset(chemin, fit: fit, width: width, height: height, cacheWidth: largeurDecodage, errorBuilder: repli);
    },
  );
}

/// Photo réseau (avatar, vignette) décodée pour un affichage de [cote] × [cote] points logiques.
ImageProvider imageReseauDimensionnee(BuildContext context, String url, double cote) {
  return ResizeImage.resizeIfNeeded(
    _largeurDecodage(context, largeur: cote, hauteur: cote),
    null,
    NetworkImage(ApiConfig.resolutionImageUrl(url)),
  );
}

/// Largeur de décodage en pixels physiques, ou null si la place disponible est inconnue.
/// Pour BoxFit.cover, le côté le plus long de la boîte (et 1,5 × sa hauteur, pour les photos
/// en paysage jusqu'au 3:2) garantit une image au moins aussi nette que l'affichage.
int? _largeurDecodage(BuildContext context, {double? largeur, double? hauteur}) {
  final cotes = [
    if (largeur != null && largeur.isFinite && largeur > 0) largeur,
    if (hauteur != null && hauteur.isFinite && hauteur > 0) hauteur * 1.5,
  ];
  if (cotes.isEmpty) return null;
  final densite = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
  return (cotes.reduce(math.max) * densite).ceil();
}
