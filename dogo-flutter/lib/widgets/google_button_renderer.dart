import 'package:flutter/widgets.dart';
import 'google_button_renderer_stub.dart'
    if (dart.library.js_interop) 'google_button_renderer_web.dart';

Widget? buildWebGoogleSignInButton({
  double? width,
  bool estSombre = false,
  bool inscription = false,
}) {
  return renderWebGoogleSignInButton(
    width: width,
    estSombre: estSombre,
    inscription: inscription,
  );
}

