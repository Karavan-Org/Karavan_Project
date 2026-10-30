import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Forme de la barre inférieure commune aux trois espaces : coins supérieurs arrondis
/// et encoche circulaire pour le bouton central (+).
const NotchedShape formeBarreNavigation = AutomaticNotchedShape(
  RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
  CircleBorder(),
);

/// Onglet du bandeau de navigation (terre sombre, Palette Dɔgɔ) : l'onglet actif
/// repose sur une pilule ocre animée (icône terre), libellé ocre : le bissap reste
/// réservé au bouton d'action central.
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

  @override
  Widget build(BuildContext context) {
    final couleur = selectionne ? AppTheme.ocre : AppTheme.creme.withValues(alpha: 0.62);
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
        highlightColor: Colors.white.withValues(alpha: 0.06),
        splashColor: AppTheme.rose.withValues(alpha: 0.16),
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
                    ? AppTheme.ocre
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  selectionne ? activeIcon : inactiveIcon,
                  key: ValueKey(selectionne),
                  color: selectionne ? AppTheme.terre : couleur,
                  size: 23,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: AppTheme.police,
                fontSize: 11,
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
