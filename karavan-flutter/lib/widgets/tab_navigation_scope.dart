import 'package:flutter/widgets.dart';

/// Scope permettant aux composants enfants (Dashboard, Profil, Drawer, Modal)
/// de piloter les onglets de la navigation principale sans importer directement
/// les classes MainNav (évite les cycles de dépendances cycliques sous le compilateur Web DDC).
class TabNavigationScope extends InheritedWidget {
  final void Function(int index) onSwitchTab;

  /// Référence statique de secours si l'appelant est en dehors de l'arborescence (ex: ModalBottomSheet, Dialog)
  static void Function(int index)? derniereNavigationActive;

  TabNavigationScope({
    super.key,
    required this.onSwitchTab,
    required super.child,
  }) {
    derniereNavigationActive = onSwitchTab;
  }

  /// Bascule l'onglet de la navigation parente active
  static void switchToTab(BuildContext? context, int index) {
    void Function(int index)? switcher;
    if (context != null) {
      try {
        final scope = context.dependOnInheritedWidgetOfExactType<TabNavigationScope>();
        switcher = scope?.onSwitchTab;
      } catch (_) {}
    }
    switcher ??= derniereNavigationActive;
    switcher?.call(index);
  }

  @override
  bool updateShouldNotify(covariant TabNavigationScope oldWidget) {
    derniereNavigationActive = onSwitchTab;
    return false;
  }
}

