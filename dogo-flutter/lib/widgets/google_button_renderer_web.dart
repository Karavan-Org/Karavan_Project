import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget? renderWebGoogleSignInButton({
  double? width,
  bool estSombre = false,
  bool inscription = false,
}) {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      theme: estSombre ? web.GSIButtonTheme.filledBlack : web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      text: inscription ? web.GSIButtonText.signupWith : web.GSIButtonText.continueWith,
      shape: web.GSIButtonShape.rectangular,
      minimumWidth: width,
    ),
  );
}

