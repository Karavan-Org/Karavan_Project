import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_compass/flutter_compass.dart';

/// Boussole du téléphone (Android : capteur de rotation, iOS : cap calibré de CoreLocation).
/// Cap en degrés, 0 = nord, sens horaire.
class BoussoleService {
  static StreamSubscription? ecouter(void Function(double cap) onCap) {
    // Le plugin n'existe que sur Android et iOS (pas de boussole sur PC).
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      return FlutterCompass.events?.listen((e) {
        final h = e.heading;
        if (h != null && !h.isNaN) onCap((h + 360) % 360);
      }, onError: (_) {});
    } catch (_) {
      // Pas de capteur (PC, émulateur) : la rotation suit alors le sens du déplacement GPS.
      return null;
    }
  }
}

