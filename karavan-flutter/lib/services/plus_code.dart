import 'package:latlong2/latlong.dart';

/// Décodage des Plus Codes Google (Open Location Code), p. ex. « JXJF+76R, Unnamed Road » :
/// l'adresse affichée par Google Maps pour les lieux sans numéro de rue, fréquents à Bamako.
class PlusCode {
  PlusCode._();

  static const _alphabet = '23456789CFGHJMPQRVWX';
  static const _valeursPaires = [20.0, 1.0, 0.05, 0.0025, 0.000125];

  /// Référence pour compléter un code court (« JXJF+76R ») : centre de Bamako.
  static const bamako = LatLng(12.6392, -8.0029);

  static final _motif = RegExp(
    '(?:^|[^0-9A-Z])([$_alphabet]{2,8})\\+([$_alphabet]{0,7})(?![0-9A-Z])',
    caseSensitive: false,
  );

  /// Premier Plus Code trouvé dans [texte] (adresse ou lien), décodé au centre de sa zone.
  static LatLng? depuisTexte(String? texte, {LatLng reference = bamako}) {
    if (texte == null || texte.isEmpty) return null;
    String t;
    try {
      t = Uri.decodeFull(texte.replaceAll('+', '%2B'));
    } catch (_) {
      t = texte;
    }
    for (final m in _motif.allMatches(t)) {
      final avant = m.group(1)!.toUpperCase();
      final apres = m.group(2)!.toUpperCase();
      if (avant.length.isOdd || apres.length == 1) continue;
      final position = avant.length == 8 ? _decoder(avant + apres) : _completer(avant, apres, reference);
      if (position != null) return position;
    }
    return null;
  }

  /// Code court : on emprunte les premiers caractères au code de la référence, puis on choisit
  /// la zone la plus proche de celle-ci (algorithme « recoverNearest » de la spécification).
  static LatLng? _completer(String avant, String apres, LatLng reference) {
    final manquants = 8 - avant.length;
    final prefixe = _encoderPrefixe(reference, manquants);
    final centre = _decoder(prefixe + avant + apres);
    if (centre == null) return null;
    final resolution = _valeursPaires[manquants ~/ 2 - 1];
    final demi = resolution / 2;
    var lat = centre.latitude;
    var lng = centre.longitude;
    if (reference.latitude + demi < lat && lat - resolution >= -90) {
      lat -= resolution;
    } else if (reference.latitude - demi > lat && lat + resolution <= 90) {
      lat += resolution;
    }
    if (reference.longitude + demi < lng) {
      lng -= resolution;
    } else if (reference.longitude - demi > lng) {
      lng += resolution;
    }
    return LatLng(lat, lng);
  }

  static String _encoderPrefixe(LatLng p, int longueur) {
    var lat = (p.latitude + 90).clamp(0.0, 179.999999);
    var lng = (p.longitude + 180) % 360;
    final sb = StringBuffer();
    for (var i = 0; i < longueur ~/ 2; i++) {
      final pv = _valeursPaires[i];
      final dLat = (lat / pv).floor().clamp(0, 19);
      final dLng = (lng / pv).floor().clamp(0, 19);
      sb
        ..write(_alphabet[dLat])
        ..write(_alphabet[dLng]);
      lat -= dLat * pv;
      lng -= dLng * pv;
    }
    return sb.toString();
  }

  /// Code complet sans le « + » (8 caractères puis 0 à 7) → centre de la zone.
  static LatLng? _decoder(String code) {
    if (code.length < 8) return null;
    var lat = 0.0, lng = 0.0;
    var pvLat = 0.0, pvLng = 0.0;
    for (var i = 0; i < code.length && i < 10; i += 2) {
      if (i + 1 >= code.length) return null;
      final a = _alphabet.indexOf(code[i]);
      final b = _alphabet.indexOf(code[i + 1]);
      if (a < 0 || b < 0) return null;
      pvLat = pvLng = _valeursPaires[i ~/ 2];
      lat += a * pvLat;
      lng += b * pvLng;
    }
    for (var i = 10; i < code.length; i++) {
      final g = _alphabet.indexOf(code[i]);
      if (g < 0) return null;
      pvLat /= 5;
      pvLng /= 4;
      lat += (g ~/ 4) * pvLat;
      lng += (g % 4) * pvLng;
    }
    if (_alphabet.indexOf(code[0]) > 8 || _alphabet.indexOf(code[1]) > 17) return null;
    return LatLng(lat + pvLat / 2 - 90, lng + pvLng / 2 - 180);
  }
}
