import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

/// Widget Flutter affichant la planète 3D tournante avec Three.js
/// (avec le cargo voguant sur la mer, l'avion, le carton Karavan et la sneaker en orbite).
class KaravanPlanet3DWidget extends StatefulWidget {
  final double? height;

  const KaravanPlanet3DWidget({
    super.key,
    this.height,
  });

  @override
  State<KaravanPlanet3DWidget> createState() => _KaravanPlanet3DWidgetState();
}

class _KaravanPlanet3DWidgetState extends State<KaravanPlanet3DWidget> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    if (kIsWeb) {
      return;
    }

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadFlutterAsset('assets/html/karavan_planet_3d.html');

      _controller = controller;
    } catch (_) {
      // En environnement de test ou sans implémentation WebView
      _controller = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        height: widget.height ?? 340,
        alignment: Alignment.center,
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.22),
                AppTheme.accentGold.withValues(alpha: 0.12),
                Colors.transparent,
              ],
              stops: const [0.35, 0.7, 1.0],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.public,
              size: 130,
              color: AppTheme.accentGold.withValues(alpha: 0.85),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height ?? 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.public,
                  size: 120,
                  color: AppTheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          if (_isLoading && _controller != null)
            const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Alias de rétrocompatibilité
typedef DogoPlanet3DWidget = KaravanPlanet3DWidget;
