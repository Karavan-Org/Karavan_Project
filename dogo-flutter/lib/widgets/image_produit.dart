import 'package:flutter/material.dart';
import '../services/api/api_config.dart';

/// Photo d'un produit : photo servie par le backend (/api/public/images/...) ou asset local.
/// Même signature qu'Image.asset ; un chemin vide affiche directement [errorBuilder].
Widget imageProduit(
  String chemin, {
  BoxFit? fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final repli = errorBuilder ??
      (_, __, ___) => const Center(child: Icon(Icons.inventory_2_outlined, color: Color(0xFFAC7F5E)));
  if (chemin.isEmpty) {
    return Builder(builder: (context) => SizedBox(width: width, height: height, child: repli(context, '', null)));
  }
  if (chemin.startsWith('http://') || chemin.startsWith('https://') || chemin.startsWith('/')) {
    return Image.network(
      ApiConfig.resolutionImageUrl(chemin),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: repli,
    );
  }
  return Image.asset(chemin, fit: fit, width: width, height: height, errorBuilder: repli);
}
