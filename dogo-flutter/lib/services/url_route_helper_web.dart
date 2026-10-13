import 'package:web/web.dart' as web;

/// Met à jour l'URL du navigateur (hash fragment #/espace) sur Flutter Web et isole l'espace de l'onglet
void synchroniserUrlWeb(String chemin) {
  try {
    final fragment = chemin.startsWith('/') ? chemin : '/$chemin';
    web.window.location.hash = fragment;
    final espace = chemin.replaceAll('/', '').trim().toLowerCase();
    if (espace.isNotEmpty) {
      web.window.sessionStorage.setItem('dogo_tab_espace', espace);
    }
  } catch (_) {}
}

