import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Implémentation pour plateformes natives (Android, iOS, Desktop)
/// Ne charge aucun paquet web/JS afin d'éviter les erreurs de compilation AOT/VM.
Future<Uint8List?> ouvrirCameraWeb(BuildContext context) async {
  return null;
}

