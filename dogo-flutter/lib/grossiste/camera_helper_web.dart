import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'camera_web_dialog.dart';

/// Implémentation Web pour les navigateurs (utilise CameraWebDialog et WebRTC)
Future<Uint8List?> ouvrirCameraWeb(BuildContext context) async {
  return CameraWebDialog.ouvrir(context);
}

