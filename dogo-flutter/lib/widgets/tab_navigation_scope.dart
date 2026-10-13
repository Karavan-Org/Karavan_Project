import 'package:flutter/widgets.dart';

/// Scope permettant aux composants enfants (Dashboard, Profil, Drawer, Modal)
/// de piloter les onglets de la navigation principale sans importer directement
/// les classes MainNav (évite les cycles de dépendances cycliques sous le compilateur Web DDC).
class TabNavigationScope extends InheritedWidget {
  final void Function(int index) onSwitchTab;

  const TabNavigationScope({
    super.key,
    required this.onSwitchTab,
    required super.child,
  });

  /// Bascule l'onglet de la navigation parente active
  static void switchToTab(BuildContext context, int index) {
    final scope = context.dependOnInheritedWidgetOfExactType<TabNavigationScope>();
    scope?.onSwitchTab(index);
  }

  @override
  bool updateShouldNotify(covariant TabNavigationScope oldWidget) => false;
}

