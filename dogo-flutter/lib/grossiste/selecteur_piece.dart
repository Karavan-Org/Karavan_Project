import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/kyc_api_service.dart';
import '../theme/app_theme.dart';
import 'camera_helper.dart';

/// Fichier choisi par le grossiste pour une pièce de son dossier
typedef FichierChoisi = ({Uint8List octets, String nom});

/// Feuille de choix : photo avec l'appareil, image de la galerie ou fichier (PDF, JPG, PNG).
/// Renvoie null si l'utilisateur annule ou si le fichier est refusé (taille / format).
Future<FichierChoisi?> choisirPiece(BuildContext context, {required String titre}) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: Color(0xFF2D231C))),
            const SizedBox(height: 4),
            const Text(
              "Photographiez le document ou importez-le (PDF, JPG, PNG — max 5 Mo)",
              style: TextStyle(color: Color(0xFF7C6E65), fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            _OptionSource(
              icone: Icons.photo_camera_rounded,
              titre: "Prendre une photo",
              sousTitre: "Ouvrir l'appareil photo",
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            _OptionSource(
              icone: Icons.photo_library_rounded,
              titre: "Choisir dans la galerie",
              sousTitre: "Une photo déjà enregistrée",
              onTap: () => Navigator.pop(ctx, 'galerie'),
            ),
            _OptionSource(
              icone: Icons.upload_file_rounded,
              titre: "Importer un fichier",
              sousTitre: "PDF, JPG ou PNG depuis vos fichiers",
              onTap: () => Navigator.pop(ctx, 'fichier'),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  try {
    final FichierChoisi? choisi = switch (source) {
      'camera' => await _depuisCamera(context),
      'galerie' => await _depuisGalerie(),
      _ => await _depuisFichiers(),
    };
    if (choisi == null || !context.mounted) return null;

    if (choisi.octets.lengthInBytes > KycApiService.tailleMaxOctets) {
      final mo = (choisi.octets.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      _signaler(context, "Le fichier fait $mo Mo : la limite est de 5 Mo.");
      return null;
    }
    if (!KycApiService.formatAccepte(choisi.octets)) {
      _signaler(context, "Format non accepté : envoyez un PDF, un JPG ou un PNG.");
      return null;
    }
    return choisi;
  } catch (e) {
    if (context.mounted) _signaler(context, "Impossible de récupérer le document : $e");
    return null;
  }
}

Future<FichierChoisi?> _depuisCamera(BuildContext context) async {
  if (kIsWeb) {
    final octets = await ouvrirCameraWeb(context);
    return octets == null ? null : (octets: octets, nom: _nomHorodate('photo', 'jpg'));
  }

  var statut = await Permission.camera.status;
  if (!statut.isGranted) statut = await Permission.camera.request();
  if (statut.isPermanentlyDenied) {
    if (context.mounted) _proposerParametres(context);
    return null;
  }
  if (!statut.isGranted) {
    if (context.mounted) _signaler(context, "Accès à la caméra refusé. Vous pouvez importer le document à la place.");
    return null;
  }

  final photo = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 85,
  );
  if (photo == null) return null;
  return (octets: await photo.readAsBytes(), nom: _nomOuDefaut(photo.name, 'photo', 'jpg'));
}

Future<FichierChoisi?> _depuisGalerie() async {
  if (kIsWeb) {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png']);
    return f == null ? null : (octets: await f.readAsBytes(), nom: f.name);
  }
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 85,
  );
  if (image == null) return null;
  return (octets: await image.readAsBytes(), nom: _nomOuDefaut(image.name, 'image', 'jpg'));
}

Future<FichierChoisi?> _depuisFichiers() async {
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
  return f == null ? null : (octets: await f.readAsBytes(), nom: f.name);
}

String _nomHorodate(String base, String ext) => '${base}_${DateTime.now().millisecondsSinceEpoch}.$ext';

String _nomOuDefaut(String nom, String base, String ext) => nom.isNotEmpty ? nom : _nomHorodate(base, ext);

void _signaler(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: const Color(0xFFC0392B), behavior: SnackBarBehavior.floating),
  );
}

void _proposerParametres(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Autorisation requise"),
      content: const Text(
        "L'accès à l'appareil photo est bloqué dans les réglages de votre téléphone. "
        "Activez-le pour photographier vos documents.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            openAppSettings();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: const Text("Ouvrir les réglages"),
        ),
      ],
    ),
  );
}

class _OptionSource extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;

  const _OptionSource({required this.icone, required this.titre, required this.sousTitre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: const Color(0xFFF5E8D3), borderRadius: BorderRadius.circular(12)),
        child: Icon(icone, color: AppTheme.primary),
      ),
      title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF2D231C))),
      subtitle: Text(sousTitre, style: const TextStyle(fontSize: 12, color: Color(0xFF9C8E84))),
    );
  }
}
