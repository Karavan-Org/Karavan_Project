import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_theme.dart';

/// Points de rupture de l'interface : les écrans sont pensés en une colonne pour mobile,
/// on borne donc leur largeur sur tablette et ordinateur plutôt que de les étirer.
abstract final class Responsive {
  /// Largeur maximale du contenu d'une page (au-delà, la page est centrée).
  static const double largeurContenu = 720;

  /// À partir de cette largeur, la barre de navigation du bas devient un rail latéral.
  static const double seuilNavigationLaterale = 840;

  static bool navigationLaterale(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= seuilNavigationLaterale;
}

/// Transition de page qui centre chaque page dans un [CadrePage], en déléguant l'animation
/// au constructeur d'origine : toutes les `MaterialPageRoute` deviennent responsives sans les modifier.
class TransitionCadree extends PageTransitionsBuilder {
  final PageTransitionsBuilder base;

  const TransitionCadree(this.base);

  @override
  DelegatedTransitionBuilder? get delegatedTransition => base.delegatedTransition;

  @override
  Duration get transitionDuration => base.transitionDuration;

  @override
  Duration get reverseTransitionDuration => base.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.sizeOf(context).width <= Responsive.largeurContenu) {
      return base.buildTransitions(route, context, animation, secondaryAnimation, child);
    }
    return base.buildTransitions(route, context, animation, secondaryAnimation, CadrePage(child: child));
  }
}

/// Centre son contenu sur [Responsive.largeurContenu] quand l'espace est plus large, avec le fond
/// du thème sur les côtés. Le [MediaQuery] est réduit d'autant : les écrans qui se dimensionnent
/// sur `MediaQuery.sizeOf(context)` restent dans leur colonne.
///
/// Un descendant [PleineLargeur] (les espaces avec leur navigation) lève la limite.
class CadrePage extends StatelessWidget {
  final Widget child;

  const CadrePage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.of(context);
    if (ecran.size.width <= Responsive.largeurContenu) {
      return child;
    }
    final contenu = _MediaQueryEcran(
      data: ecran,
      child: MediaQuery(
        data: ecran.copyWith(size: Size(Responsive.largeurContenu, ecran.size.height)),
        child: child,
      ),
    );
    return _Cadre(couleurFond: AppTheme.couleurFond(context), child: contenu);
  }
}

/// Lève la limite de largeur du [CadrePage] englobant et rend au contenu le [MediaQuery] de l'écran.
///
/// La demande est faite dans `initState`, avant la première mise en page : aucune image n'est rendue
/// dans le cadre étroit.
class PleineLargeur extends StatefulWidget {
  final Widget child;

  const PleineLargeur({super.key, required this.child});

  @override
  State<PleineLargeur> createState() => _PleineLargeurState();
}

class _PleineLargeurState extends State<PleineLargeur> {
  _RenderCadre? _cadre;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nouveauCadre = context.findAncestorRenderObjectOfType<_RenderCadre>();
    if (nouveauCadre != _cadre) {
      _cadre?.demandesPleineLargeur -= 1;
      _cadre = nouveauCadre;
      _cadre?.demandesPleineLargeur += 1;
    }
  }

  @override
  void dispose() {
    _cadre?.demandesPleineLargeur -= 1;
    _cadre = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ecran = context.dependOnInheritedWidgetOfExactType<_MediaQueryEcran>()?.data;
    return ecran == null ? widget.child : MediaQuery(data: ecran, child: widget.child);
  }
}

/// Conserve le [MediaQuery] de l'écran entier pour [PleineLargeur].
class _MediaQueryEcran extends InheritedWidget {
  final MediaQueryData data;

  const _MediaQueryEcran({required this.data, required super.child});

  @override
  bool updateShouldNotify(_MediaQueryEcran oldWidget) => oldWidget.data != data;
}

class _Cadre extends SingleChildRenderObjectWidget {
  final Color couleurFond;

  const _Cadre({required this.couleurFond, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCadre(couleurFond);

  @override
  void updateRenderObject(BuildContext context, _RenderCadre renderObject) {
    renderObject.couleurFond = couleurFond;
  }
}

class _RenderCadre extends RenderShiftedBox {
  _RenderCadre(this._couleurFond) : super(null);

  Color _couleurFond;
  set couleurFond(Color valeur) {
    if (valeur == _couleurFond) return;
    _couleurFond = valeur;
    markNeedsPaint();
  }

  int _demandesPleineLargeur = 0;
  int get demandesPleineLargeur => _demandesPleineLargeur;
  set demandesPleineLargeur(int valeur) {
    _demandesPleineLargeur = valeur;
    if (attached) markNeedsLayout();
  }

  bool _limite = false;

  @override
  void performLayout() {
    final enfant = child;
    _limite = _demandesPleineLargeur == 0 &&
        constraints.maxWidth.isFinite &&
        constraints.maxWidth > Responsive.largeurContenu;
    if (enfant == null) {
      size = constraints.smallest;
      return;
    }
    final donnees = enfant.parentData! as BoxParentData;
    if (!_limite) {
      final contraintesStrictes = BoxConstraints(
        minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth,
        maxWidth: constraints.hasBoundedWidth ? constraints.maxWidth : constraints.maxWidth,
        minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight,
        maxHeight: constraints.hasBoundedHeight ? constraints.maxHeight : constraints.maxHeight,
      );
      enfant.layout(contraintesStrictes, parentUsesSize: true);
      size = Size(contraintesStrictes.maxWidth, contraintesStrictes.maxHeight);
      donnees.offset = Offset.zero;
      return;
    }
    enfant.layout(
      constraints.copyWith(
        minWidth: Responsive.largeurContenu,
        maxWidth: Responsive.largeurContenu,
        minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight,
        maxHeight: constraints.hasBoundedHeight ? constraints.maxHeight : constraints.maxHeight,
      ),
      parentUsesSize: true,
    );
    final double hauteur =
        constraints.hasBoundedHeight ? constraints.maxHeight : enfant.size.height;
    size = constraints.constrain(Size(constraints.maxWidth, hauteur));
    donnees.offset = Offset((size.width - Responsive.largeurContenu) / 2, 0);
  }

  // Les marges latérales absorbent les touchers : ils ne traversent pas vers la page du dessous.
  @override
  bool hitTestSelf(Offset position) => _limite;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_limite) context.canvas.drawRect(offset & size, Paint()..color = _couleurFond);
    super.paint(context, offset);
  }
}
