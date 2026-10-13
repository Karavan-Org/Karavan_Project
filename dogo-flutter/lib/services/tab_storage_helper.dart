import 'tab_storage_helper_stub.dart'
    if (dart.library.js_interop) 'tab_storage_helper_web.dart';

/// Récupère un élément du stockage isolé de l'onglet courant (sessionStorage sur le web)
String? getSessionStorageItem(String key) => tabStorageGetItem(key);

/// Enregistre un élément dans le stockage isolé de l'onglet courant
void setSessionStorageItem(String key, String value) => tabStorageSetItem(key, value);

/// Supprime un élément du stockage isolé de l'onglet courant
void removeSessionStorageItem(String key) => tabStorageRemoveItem(key);

/// Détecte l'espace ciblé par l'onglet web à partir de son URL propre (#/espace ou /espace)
String? detecterEspaceUrlOnglet() => tabStorageDetecterEspaceUrl();

