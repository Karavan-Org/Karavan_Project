import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import '../../theme/app_theme.dart';

/// Dialogue modal plein écran permettant de prévisualiser la caméra en direct (WebRTC)
/// et de capturer une vraie photo instantanée, avec retour possible, bouton déclencheur
/// toujours visible et fermeture par clic extérieur ou touche Échap.
class CameraWebDialog extends StatefulWidget {
  const CameraWebDialog({super.key});

  static Future<Uint8List?> ouvrir(BuildContext context) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: true, // Permet de fermer en cliquant à l'extérieur sans rafraîchir la page
      builder: (_) => const CameraWebDialog(),
    );
  }

  @override
  State<CameraWebDialog> createState() => _CameraWebDialogState();
}

class _CameraWebDialogState extends State<CameraWebDialog> {
  late String _viewType;
  web.HTMLVideoElement? _videoElement;
  web.MediaStream? _mediaStream;
  bool _cameraPrete = false;
  bool _enChargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _initialiserCamera();
  }

  Future<void> _initialiserCamera() async {
    setState(() {
      _erreur = null;
      _cameraPrete = false;
      _enChargement = true;
      _viewType = 'web-camera-view-${DateTime.now().microsecondsSinceEpoch}';
    });

    _arreterCamera();

    try {
      final nav = web.window.navigator;

      // 1. Configuration de l'élément HTML <video>
      _videoElement = web.HTMLVideoElement()
        ..autoplay = true
        ..playsInline = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.pointerEvents = 'none' // Empêche l'élément HTML de bloquer les clics Flutter
        ..style.borderRadius = '16px';

      // Enregistrement de la vue HTML pour Flutter Web
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => _videoElement!,
      );

      // 2. Demande d'accès au flux caméra
      final constraints = web.MediaStreamConstraints(
        video: true.toJS,
        audio: false.toJS,
      );

      final streamPromise = nav.mediaDevices.getUserMedia(constraints);
      final stream = await streamPromise.toDart;
      _mediaStream = stream;
      _videoElement!.srcObject = stream;

      // 3. Détection du chargement vidéo
      _videoElement!.onloadedmetadata = (web.Event _) {
        if (mounted) {
          setState(() {
            _cameraPrete = true;
            _enChargement = false;
          });
        }
      }.toJS;

      await _videoElement!.play().toDart;

      if (mounted) {
        setState(() {
          _cameraPrete = true;
          _enChargement = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        String messageExplicatif;

        if (errStr.contains("NotAllowedError") || errStr.contains("Permission denied") || errStr.contains("PermissionDeniedError")) {
          messageExplicatif = "L'accès à la webcam a été refusé par le navigateur.\n\n"
              "Veuillez autoriser la caméra dans la barre d'adresse de Chrome puis cliquer sur \"Réessayer\".";
        } else if (errStr.contains("NotFoundError") || errStr.contains("DevicesNotFoundError")) {
          messageExplicatif = "Aucune webcam détectée sur cet ordinateur.\n"
              "Vous pouvez importer une photo depuis vos fichiers ci-dessous.";
        } else if (errStr.contains("NotReadableError") || errStr.contains("TrackStartError")) {
          messageExplicatif = "La webcam est déjà utilisée par une autre application (Zoom, Teams, etc.).\n"
              "Veuillez fermer l'autre application puis cliquer sur \"Réessayer\".";
        } else {
          messageExplicatif = "Impossible de démarrer la caméra : $errStr";
        }

        setState(() {
          _erreur = messageExplicatif;
          _cameraPrete = false;
          _enChargement = false;
        });
      }
    }
  }

  void _capturerPhoto() {
    if (_videoElement == null) return;

    try {
      int videoWidth = _videoElement!.videoWidth;
      int videoHeight = _videoElement!.videoHeight;

      if (videoWidth <= 0 || videoHeight <= 0) {
        videoWidth = _videoElement!.clientWidth;
        videoHeight = _videoElement!.clientHeight;
        if (videoWidth <= 0) videoWidth = 1280;
        if (videoHeight <= 0) videoHeight = 720;
      }

      final canvas = web.HTMLCanvasElement()
        ..width = videoWidth
        ..height = videoHeight;

      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
      if (ctx == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur d'initialisation du Canvas de capture")),
        );
        return;
      }

      ctx.drawImage(_videoElement! as web.CanvasImageSource, 0, 0);

      final dataUrl = canvas.toDataURL('image/jpeg', 0.92.toJS);
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex != -1) {
        final base64String = dataUrl.substring(commaIndex + 1);
        final bytes = base64Decode(base64String);
        _fermerEtRetourner(bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la capture : $e"), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _importerDepuisFichiers() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        _fermerEtRetourner(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'import : $e")),
        );
      }
    }
  }

  void _fermerEtRetourner(Uint8List? bytes) {
    _arreterCamera();
    if (mounted) {
      Navigator.of(context).pop(bytes);
    }
  }

  void _arreterCamera() {
    try {
      if (_mediaStream != null) {
        final tracks = _mediaStream!.getTracks().toDart;
        for (final track in tracks) {
          track.stop();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _arreterCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.of(context).size;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _arreterCamera();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: ecran.height * 0.92,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.terre,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. En-tête : Titre et Bouton Fermer (X)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Prendre une photo du produit",
                                style: TextStyle(fontFamily: AppTheme.policeTitre, 
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "Cadrez l'article puis appuyez sur le bouton déclencheur",
                                style: TextStyle(color: Colors.white54, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white12,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                          tooltip: "Fermer la caméra (Retour)",
                          onPressed: () => _fermerEtRetourner(null),
                        ),
                      ],
                    ),
                  ),

                  // 2. Zone d'affichage vidéo / erreur / chargement (Responsive)
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: (ecran.height * 0.55).clamp(240.0, 360.0),
                        minHeight: 220,
                      ),
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_erreur != null)
                              Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off_rounded, color: AppTheme.ocreProfond, size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        _erreur!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                      ),
                                      const SizedBox(height: 18),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: _initialiserCamera,
                                            icon: const Icon(Icons.refresh_rounded, size: 18),
                                            label: const Text("Réessayer"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(0, 38),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: _importerDepuisFichiers,
                                            icon: const Icon(Icons.folder_open_rounded, size: 18, color: Colors.white),
                                            label: const Text("Importer une image", style: TextStyle(color: Colors.white)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Colors.white30),
                                              minimumSize: const Size(0, 38),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (_enChargement)
                              const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: AppTheme.olive),
                                    SizedBox(height: 14),
                                    Text(
                                      "Démarrage de la caméra...",
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            else
                              HtmlElementView(viewType: _viewType),

                            // Cadre de visée centré si la caméra est prête
                            if (_cameraPrete && _erreur == null)
                              IgnorePointer(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white38, width: 1.5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Text(
                                        "Cadrez l'article ici",
                                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Barre de commandes en bas (TOUJOURS VISIBLE ET CLAIRE)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Row(
                      children: [
                        // Bouton Annuler / Retour
                        TextButton.icon(
                          onPressed: () => _fermerEtRetourner(null),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          label: const Text(
                            "Annuler",
                            style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Grand bouton Déclencheur "Prendre la photo"
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _cameraPrete ? _capturerPhoto : null,
                            icon: const Icon(Icons.camera_alt_rounded, size: 22),
                            label: Text(
                              _cameraPrete ? "Prendre la photo" : "Démarrage...",
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cameraPrete ? AppTheme.danger : AppTheme.terreDouce,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
