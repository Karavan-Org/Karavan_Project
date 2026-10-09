import 'package:flutter/foundation.dart';

/// Produit sélectionné dans « Mon catalogue actif » : le bouton central (+) crée alors directement
/// le groupe d'achat de ce produit.
class SelectionProduitGrossiste {
  SelectionProduitGrossiste._();

  static final ValueNotifier<Map<String, dynamic>?> produit = ValueNotifier<Map<String, dynamic>?>(null);

  static void basculer(Map<String, dynamic> p) =>
      produit.value = (produit.value != null && produit.value!['id'] == p['id']) ? null : p;

  static void effacer() => produit.value = null;
}
