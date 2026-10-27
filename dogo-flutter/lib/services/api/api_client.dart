import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_exception.dart';
import 'api_http_client.dart';

/// Client HTTP centralisé de l'application DoGo
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _httpClient = creerClientHttp();

  /// Jeton JWT actuel (injecté après authentification)
  String? _jeton;

  String? get jeton => _jeton;
  bool get estAuthentifie => _jeton != null && _jeton!.isNotEmpty;

  void definirJeton(String? jeton) {
    _jeton = jeton;
  }

  void deconnecter() {
    _jeton = null;
  }

  /// Prépare les en-têtes communs (Content-Type, Accept, Authorization, Idempotency-Key)
  Map<String, String> _construireEnTetes(
      Map<String, String>? entetesPersonnalisees) {
    final Map<String, String> entetes = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    if (_jeton != null && _jeton!.isNotEmpty) {
      entetes['Authorization'] = 'Bearer $_jeton';
    }

    if (entetesPersonnalisees != null) {
      entetes.addAll(entetesPersonnalisees);
    }

    return entetes;
  }

  Uri _construireUri(String chemin, [Map<String, dynamic>? parametresRequete]) {
    final urlComplete = '${ApiConfig.baseUrl}$chemin';
    final uri = Uri.parse(urlComplete);

    if (parametresRequete != null && parametresRequete.isNotEmpty) {
      final queryParameters = Map<String, String>.from(uri.queryParameters);
      parametresRequete.forEach((cle, valeur) {
        if (valeur != null) {
          queryParameters[cle] = valeur.toString();
        }
      });
      return uri.replace(queryParameters: queryParameters);
    }

    return uri;
  }

  /// Callback appelé lorsqu'un rafraîchissement de jeton est requis sur 401
  Future<bool> Function()? onRefreshRequired;

  bool _enRafraichissement = false;
  Completer<bool>? _completerRafraichissement;

  Future<bool> _rafraichirJeton() async {
    final callback = onRefreshRequired;
    if (callback == null) return false;
    if (_enRafraichissement) {
      return await (_completerRafraichissement?.future ?? Future.value(false));
    }
    _enRafraichissement = true;
    _completerRafraichissement = Completer<bool>();
    try {
      final res = await callback();
      _completerRafraichissement?.complete(res);
      return res;
    } catch (_) {
      _completerRafraichissement?.complete(false);
      return false;
    } finally {
      _enRafraichissement = false;
      _completerRafraichissement = null;
    }
  }

  /// Message commun à toutes les coupures réseau (mobile : SocketException, web : ClientException).
  static const String messageServeurInjoignable =
      'Impossible de joindre le serveur Karavan. Vérifiez votre connexion internet.';

  /// Exécute [action] (reconstruite à chaque appel, donc rejouable) et traduit les erreurs réseau
  /// en [ApiException]. Un 401 hors /api/auth/ déclenche un unique rafraîchissement puis un rejeu.
  Future<dynamic> _executerRequete(
    String endpoint,
    Future<http.Response> Function() action, {
    Duration timeout = ApiConfig.timeout,
    bool rafraichirSur401 = true,
  }) async {
    try {
      http.Response response = await action().timeout(timeout);

      if (rafraichirSur401 &&
          response.statusCode == 401 &&
          !endpoint.startsWith('/api/auth/')) {
        final reussi = await _rafraichirJeton();
        if (reussi) {
          // Rejouer la requête une seule fois avec le nouveau token
          response = await action().timeout(timeout);
        }
      }

      return _traiterReponse(response);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
          statusCode: 0, message: messageServeurInjoignable);
    } on http.ClientException {
      throw const ApiException(
          statusCode: 0, message: messageServeurInjoignable);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message:
            'Délai d\'attente dépassé lors de la requête au serveur Karavan.',
      );
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Erreur réseau : ${e.toString()}',
      );
    }
  }

  // --- REQUÊTE SANS AUTH (connexion, refresh, logout) ---
  Future<dynamic> postSansAuth(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) {
    final bodyEncode = body != null ? jsonEncode(body) : null;
    final Map<String, String> entetes = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      ...?headers,
    };
    return _executerRequete(
      endpoint,
      () => _httpClient.post(_construireUri(endpoint),
          headers: entetes, body: bodyEncode),
      rafraichirSur401: false,
    );
  }

  // --- REQUÊTE GET ---
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) {
    return _executerRequete(
      endpoint,
      () => _httpClient.get(_construireUri(endpoint, queryParams),
          headers: _construireEnTetes(headers)),
    );
  }

  // --- REQUÊTE POST ---
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) {
    final bodyEncode = body != null ? jsonEncode(body) : null;
    return _executerRequete(
      endpoint,
      () => _httpClient.post(_construireUri(endpoint),
          headers: _construireEnTetes(headers), body: bodyEncode),
    );
  }

  // --- REQUÊTE PUT ---
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) {
    final bodyEncode = body != null ? jsonEncode(body) : null;
    return _executerRequete(
      endpoint,
      () => _httpClient.put(_construireUri(endpoint),
          headers: _construireEnTetes(headers), body: bodyEncode),
    );
  }

  // --- REQUÊTE PATCH ---
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) {
    final bodyEncode = body != null ? jsonEncode(body) : null;
    return _executerRequete(
      endpoint,
      () => _httpClient.patch(_construireUri(endpoint),
          headers: _construireEnTetes(headers), body: bodyEncode),
    );
  }

  // --- REQUÊTE DELETE ---
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) {
    return _executerRequete(
      endpoint,
      () => _httpClient.delete(_construireUri(endpoint),
          headers: _construireEnTetes(headers)),
    );
  }

  // --- REQUÊTE MULTIPART (Upload photo / fichier) ---
  Future<dynamic> postMultipart(
    String endpoint, {
    required List<int> fileBytes,
    required String filename,
    required String fieldName,
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) {
    return postMultipartFichiers(
      endpoint,
      fieldName: fieldName,
      fichiers: [(bytes: fileBytes, filename: filename)],
      fields: fields,
      headers: headers,
      timeout: ApiConfig.timeout,
    );
  }

  // --- REQUÊTE MULTIPART À PLUSIEURS FICHIERS (Dossier KYC) ---
  /// Chaque fichier est envoyé sous le même nom de champ [fieldName] ; [fields] accompagne la requête.
  Future<dynamic> postMultipartFichiers(
    String endpoint, {
    required String fieldName,
    required List<({List<int> bytes, String filename})> fichiers,
    Map<String, String>? fields,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
  }) {
    // Une MultipartRequest ne s'envoie qu'une fois : elle est reconstruite à chaque tentative
    // (le rejeu après rafraîchissement du jeton porte ainsi le nouvel en-tête Authorization).
    Future<http.Response> envoyer() async {
      final request = http.MultipartRequest('POST', _construireUri(endpoint));
      request.headers['Accept'] = 'application/json';
      if (_jeton != null && _jeton!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_jeton';
      }
      if (headers != null) {
        request.headers.addAll(headers);
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }
      for (final f in fichiers) {
        request.files.add(http.MultipartFile.fromBytes(fieldName, f.bytes,
            filename: f.filename));
      }
      return http.Response.fromStream(await _httpClient.send(request));
    }

    return _executerRequete(endpoint, envoyer, timeout: timeout);
  }

  /// Analyse la réponse HTTP et extrait le JSON ou déclenche l'exception standardisée
  dynamic _traiterReponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        return response.body;
      }
    }

    // La console du navigateur / de l'IDE affiche la raison du refus renvoyée par le backend
    final corps = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (kDebugMode) {
      debugPrint(
          'API ${response.request?.method} ${response.request?.url.path} -> $statusCode $corps');
    }
    throw ApiException.fromResponseBody(statusCode, corps);
  }
}
