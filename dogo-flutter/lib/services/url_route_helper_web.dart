import 'package:web/web.dart' as web;

/// Met à jour l'URL du navigateur (hash fragment #/espace) sur Flutter Web et isole l'espace de l'onglet.
///
/// L'adresse est remplacée par `history.replaceState`, en conservant l'état d'historique de Flutter :
/// contrairement à `location.hash = …`, cela n'émet aucun événement de navigation. Sinon Flutter Web
/// « entend » le changement d'adresse et rouvre la route par-dessus l'écran qui vient de la définir
/// (deux espaces empilés : appels réseau en double et clés globales dupliquées).
void synchroniserUrlWeb(String chemin) {
  try {
    final fragment = chemin.startsWith('/') ? chemin : '/$chemin';
    if (web.window.location.hash != '#$fragment') {
      web.window.history.replaceState(web.window.history.state, '', '#$fragment');
    }
    final espace = chemin.replaceAll('/', '').trim().toLowerCase();
    if (espace.isNotEmpty) {
      web.window.sessionStorage.setItem('dogo_tab_espace', espace);
    }
  } catch (_) {}
}
