import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Boussole du navigateur mobile. Cap en degrés, 0 = nord, sens horaire.
///  * Chrome Android : événement `deviceorientationabsolute` (alpha relatif au nord, sens anti-horaire).
///  * Safari iOS : `webkitCompassHeading` (déjà un cap nord, sens horaire).
/// L'événement `deviceorientation` simple n'est pas utilisé : son alpha est relatif à la position
/// initiale du téléphone, pas au nord.
class BoussoleService {
  static StreamSubscription? ecouter(void Function(double cap) onCap) {
    try {
      final absolu = const web.EventStreamProvider<web.DeviceOrientationEvent>('deviceorientationabsolute')
          .forTarget(web.window)
          .listen((e) {
        final alpha = e.alpha;
        if (e.absolute && alpha != null && !alpha.isNaN) onCap((360 - alpha) % 360);
      });
      final ios = const web.EventStreamProvider<web.DeviceOrientationEvent>('deviceorientation')
          .forTarget(web.window)
          .listen((e) {
        final cap = (e as JSObject).getProperty<JSNumber?>('webkitCompassHeading'.toJS)?.toDartDouble;
        if (cap != null && !cap.isNaN) onCap(cap % 360);
      });
      return _Double(absolu, ios);
    } catch (_) {
      return null;
    }
  }
}

/// Regroupe les deux abonnements pour que l'appelant n'ait qu'un `cancel()` à faire.
class _Double implements StreamSubscription<void> {
  final StreamSubscription a;
  final StreamSubscription b;

  _Double(this.a, this.b);

  @override
  Future<void> cancel() async {
    await a.cancel();
    await b.cancel();
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) => a.asFuture(futureValue);

  @override
  bool get isPaused => a.isPaused;

  @override
  void onData(void Function(void data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {
    a.pause(resumeSignal);
    b.pause(resumeSignal);
  }

  @override
  void resume() {
    a.resume();
    b.resume();
  }
}

