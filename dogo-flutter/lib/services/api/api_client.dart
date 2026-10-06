import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_exception.dart';

/// Client HTTP centralisé de l'application DoGo
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _httpClient = http.Client();

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
  Map<String, String> _construireEnTetes(Map<String, String>? entetesPersonnalisees) {
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

  // --- REQUÊTE GET ---
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _construireUri(endpoint, queryParams);
      final response = await _httpClient
          .get(uri, headers: _construireEnTetes(headers))
          .timeout(ApiConfig.timeout);

      return _traiterReponse(response);
    } on SocketException {
      throw const ApiException(
        statusCode: 0,
        message: 'Impossible de joindre le serveur DoGo. Vérifiez votre connexion internet.',
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message: 'Délai d\'attente dépassé. Le serveur DoGo met trop de temps à répondre.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Erreur réseau : ${e.toString()}',
      );
    }
  }

  // --- REQUÊTE POST ---
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _construireUri(endpoint);
      final bodyEncode = body != null ? jsonEncode(body) : null;

      final response = await _httpClient
          .post(uri, headers: _construireEnTetes(headers), body: bodyEncode)
          .timeout(ApiConfig.timeout);

      return _traiterReponse(response);
    } on SocketException {
      throw const ApiException(
        statusCode: 0,
        message: 'Impossible de joindre le serveur DoGo. Vérifiez votre connexion internet.',
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message: 'Délai d\'attente dépassé lors de l\'envoi au serveur DoGo.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Erreur réseau : ${e.toString()}',
      );
    }
  }

  // --- REQUÊTE PUT ---
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _construireUri(endpoint);
      final bodyEncode = body != null ? jsonEncode(body) : null;

      final response = await _httpClient
          .put(uri, headers: _construireEnTetes(headers), body: bodyEncode)
          .timeout(ApiConfig.timeout);

      return _traiterReponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Erreur réseau : ${e.toString()}',
      );
    }
  }

  // --- REQUÊTE DELETE ---
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _construireUri(endpoint);
      final response = await _httpClient
          .delete(uri, headers: _construireEnTetes(headers))
          .timeout(ApiConfig.timeout);

      return _traiterReponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Erreur réseau : ${e.toString()}',
      );
    }
  }

  // --- REQUÊTE MULTIPART (Upload photo / fichier) ---
  Future<dynamic> postMultipart(
    String endpoint, {
    required List<int> fileBytes,
    required String filename,
    required String fieldName,
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = _construireUri(endpoint);
      final request = http.MultipartRequest('POST', uri);

      if (_jeton != null && _jeton!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_jeton';
      }
      if (headers != null) {
        request.headers.addAll(headers);
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }

      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: filename,
      ));

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _traiterReponse(response);
    } on SocketException {
      throw const ApiException(
        statusCode: 0,
        message: 'Impossible de joindre le serveur DoGo. Vérifiez votre connexion internet.',
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message: 'Délai d\'attente dépassé lors de l\'envoi de la photo.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Erreur réseau : ${e.toString()}',
      );
    }
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

    throw ApiException.fromResponseBody(statusCode, response.body);
  }
}
