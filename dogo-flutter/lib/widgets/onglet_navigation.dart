import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Forme de la barre inférieure commune aux trois espaces : coins supérieurs arrondis
/// et encoche circulaire pour le bouton central (+).
const NotchedShape formeBarreNavigation = AutomaticNotchedShape(
  RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
  CircleBorder(),
);

/// Onglet de la barre inférieure : l'icône active repose sur une pilule crème animée.
class OngletNavigation extends StatelessWidget {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool selectionne;
  final VoidCallback onTap;

  const OngletNavigation({
    super.key,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.selectionne,
    required this.onTap,
  });

  static const Color _inactif = Color(0xFF8C7E74);

  @override
  Widget build(BuildContext context) {
    final couleurInactif = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkTextMuted
        : _inactif;
    final couleur = selectionne
        ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkPrimary : AppTheme.primaryDark)
        : couleurInactif;
    return Semantics(
      selected: selectionne,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.rectangle,
        containedInkWell: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: selectionne ? 54 : 40,
              height: 30,
              decoration: BoxDecoration(
                color: selectionne
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF38291E)
                      : AppTheme.tertiary)
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  selectionne ? activeIcon : inactiveIcon,
                  key: ValueKey(selectionne),
                  color: couleur,
                  size: 23,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: -0.1,
                fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500,
                color: couleur,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}
