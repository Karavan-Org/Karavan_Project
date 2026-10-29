import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

/// Bascule entre le mode clair et le mode sombre.
/// L'icône montre l'action proposée : une lune en mode clair, un soleil en mode sombre.
class BoutonBasculeTheme extends StatelessWidget {
  final bool compact;

  const BoutonBasculeTheme({
    super.key,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, mode, _) {
        final estSombre = ThemeService.instance.estSombre(context);
        final couleurIcone = AppTheme.couleurTexte(context);
        final bordure = AppTheme.couleurBordure(context);

        final icone = AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            estSombre ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            key: ValueKey(estSombre ? 'theme_sombre' : 'theme_clair'),
            size: 18,
            color: couleurIcone,
          ),
        );

        final contenu = compact
            ? SizedBox(width: 38, height: 38, child: Center(child: icone))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icone,
                    const SizedBox(width: 8),
                    Text(
                      estSombre ? 'Mode sombre' : 'Mode clair',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: couleurIcone,
                      ),
                    ),
                  ],
                ),
              );

        final forme = compact
            ? CircleBorder(side: BorderSide(color: bordure))
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: bordure),
              );

        return Tooltip(
          message: estSombre ? 'Passer en mode clair' : 'Passer en mode sombre',
          child: Material(
            color: AppTheme.couleurCarte(context),
            shape: forme,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => ThemeService.instance.basculerMode(context),
              child: contenu,
            ),
          ),
        );
      },
    );
  }
}
