import 'dart:async';
import 'package:flutter/widgets.dart';

/// Vrai si l'écran de [context] est réellement vu : application au premier plan et route
/// au sommet de la pile (pas recouverte par un autre écran, un dialogue ou une feuille).
///
/// Les écrans qui s'actualisent toutes les quelques secondes sautent leurs ticks quand ils ne
/// sont pas vus : aucun appel réseau inutile en arrière-plan, et le premier tick après le
/// retour sur l'écran le remet à jour.
bool ecranVisible(BuildContext context) {
  final etat = WidgetsBinding.instance.lifecycleState;
  if (etat != null && etat != AppLifecycleState.resumed) return false;
  final route = ModalRoute.of(context);
  return route == null || route.isCurrent;
}

/// Actualisation automatique d'un écran : [actualiserEnSilence] est appelée toutes les
/// [intervalleActualisation] tant que l'écran est vu ([ecranVisible]), jamais deux fois en parallèle.
/// L'écran appelle [demarrerActualisation] dans `initState` ; l'arrêt est automatique.
mixin ActualisationAutomatique<T extends StatefulWidget> on State<T> {
  Timer? _minuterie;
  bool _enCours = false;

  Duration get intervalleActualisation => const Duration(seconds: 30);

  /// Relit les données sans indicateur de chargement ni effacement en cas d'erreur passagère
  Future<void> actualiserEnSilence();

  void demarrerActualisation() {
    _minuterie?.cancel();
    _minuterie = Timer.periodic(intervalleActualisation, (_) async {
      if (!mounted || _enCours || !ecranVisible(context)) return;
      _enCours = true;
      try {
        await actualiserEnSilence();
      } catch (_) {
        // Réseau momentané : le prochain tick réessaiera
      } finally {
        _enCours = false;
      }
    });
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }
}
