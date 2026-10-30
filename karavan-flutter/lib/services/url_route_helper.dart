import 'url_route_helper_stub.dart'
    if (dart.library.js_interop) 'url_route_helper_web.dart';

/// Met à jour la route / fragment dans l'URL du navigateur (ex: #/commercant, #/courtier, #/grossiste)
void definirRouteWeb(String route) {
  synchroniserUrlWeb(route);
}

