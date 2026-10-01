import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

/// Widget Flutter affichant la planète 3D tournante avec Three.js
/// (avec le cargo voguant sur la mer, l'avion, le carton DoGo et la sneaker en orbite).
class DogoPlanet3DWidget extends StatefulWidget {
  final double height;

  const DogoPlanet3DWidget({
    super.key,
    this.height = 380,
  });

  @override
  State<DogoPlanet3DWidget> createState() => _DogoPlanet3DWidgetState();
}

class _DogoPlanet3DWidgetState extends State<DogoPlanet3DWidget> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    if (kIsWeb) {
      // Sur Flutter Web, une vue HtmlElementView sera utilisée
      return;
    }

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
      ..loadFlutterAsset('assets/html/dogo_planet_3d.html');

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            _buildWebFallback(),

          // Indicateur de chargement discret lors de l'initialisation du WebGL
          if (_isLoading && !kIsWeb)
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebFallback() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tertiary.withValues(alpha: 0.4),
              ),
              child: const Icon(
                Icons.public,
                size: 80,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Animation 3D Three.js active",
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
