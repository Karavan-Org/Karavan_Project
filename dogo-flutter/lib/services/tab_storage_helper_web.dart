import 'package:web/web.dart' as web;

/// Implémentation web pour l'isolation de session par onglet via window.sessionStorage et l'URL
String? tabStorageGetItem(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void tabStorageSetItem(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {}
}

void tabStorageRemoveItem(String key) {
  try {
    web.window.sessionStorage.removeItem(key);
  } catch (_) {}
}

String? tabStorageDetecterEspaceUrl() {
  try {
    final hash = web.window.location.hash.toLowerCase();
    final path = web.window.location.pathname.toLowerCase();
    if (hash.contains('courtier') || path.contains('courtier')) return 'courtier';
    if (hash.contains('grossiste') || path.contains('grossiste')) return 'grossiste';
    if (hash.contains('commercant') || path.contains('commercant')) return 'commercant';
  } catch (_) {}
  return null;
}

