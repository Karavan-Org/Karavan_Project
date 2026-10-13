import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../grossiste/camera_helper.dart';
import '../services/api/api_config.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Composant d'Avatar de profil interactif permettant aux acteurs
/// (Commerçants, Grossistes, Courtiers) de personnaliser leur photo de profil,
/// prendre une photo en direct (caméra / webcam) ou importer depuis la galerie / fichiers.
class AvatarProfilInteractif extends StatefulWidget {
  final String? photoUrl;
  final double taille;
  final CustomPainter customPainterDefaut;
  final bool editable;
  final VoidCallback? onPhotoChangee;

  const AvatarProfilInteractif({
    super.key,
    this.photoUrl,
    this.taille = 86.0,
    required this.customPainterDefaut,
    this.editable = true,
    this.onPhotoChangee,
  });

  @override
  State<AvatarProfilInteractif> createState() => _AvatarProfilInteractifState();
}

class _AvatarProfilInteractifState extends State<AvatarProfilInteractif> {
  bool _enChargement = false;
  Uint8List? _previewOctets;

  Future<void> _ouvrirSelecteurPhoto() async {
    final String? choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
              const Text(
                "Photo de profil",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF2C241E)),
              ),
              const SizedBox(height: 4),
              const Text(
                "Personnalisez votre photo de profil visible par vos partenaires et l'administrateur.",
                style: TextStyle(color: Color(0xFF7C6E65), fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E8D3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: AppTheme.primary),
                ),
                title: const Text("Prendre une photo", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: const Text("Caméra ou webcam en direct", style: TextStyle(fontSize: 12, color: Color(0xFF9C8E84))),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E8D3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                ),
                title: const Text("Choisir dans la galerie", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: const Text("Importer une image enregistrée", style: TextStyle(fontSize: 12, color: Color(0xFF9C8E84))),
                onTap: () => Navigator.pop(ctx, 'galerie'),
              ),
              if ((widget.photoUrl != null && widget.photoUrl!.isNotEmpty) || _previewOctets != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  ),
                  title: const Text("Supprimer la photo", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFFDC2626))),
                  subtitle: const Text("Revenir à l'avatar par défaut", style: TextStyle(fontSize: 12, color: Color(0xFF9C8E84))),
                  onTap: () => Navigator.pop(ctx, 'supprimer'),
                ),
            ],
          ),
        ),
      ),
    );

    if (choix == null || !mounted) return;

    if (choix == 'supprimer') {
      await _supprimerPhoto();
      return;
    }

    try {
      Uint8List? octets;
      String nom = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (choix == 'camera') {
        if (kIsWeb) {
          octets = await ouvrirCameraWeb(context);
        } else {
          var statut = await Permission.camera.status;
          if (!statut.isGranted) statut = await Permission.camera.request();
          if (statut.isGranted) {
            final xfile = await ImagePicker().pickImage(
              source: ImageSource.camera,
              maxWidth: 1024,
              maxHeight: 1024,
              imageQuality: 85,
            );
            if (xfile != null) {
              octets = await xfile.readAsBytes();
              nom = xfile.name.isNotEmpty ? xfile.name : nom;
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Accès à la caméra refusé. Vous pouvez choisir une image dans la galerie."),
                  backgroundColor: Color(0xFFDC2626),
                ),
              );
            }
            return;
          }
        }
      } else if (choix == 'galerie') {
        if (kIsWeb) {
          final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
          if (files.isNotEmpty) {
            final f = files.first;
            octets = await f.readAsBytes();
            nom = f.name;
          }
        } else {
          final xfile = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
          if (xfile != null) {
            octets = await xfile.readAsBytes();
            nom = xfile.name.isNotEmpty ? xfile.name : nom;
          }
        }
      }

      if (octets == null || !mounted) return;

      if (octets.lengthInBytes > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("L'image est trop volumineuse. La taille maximale est de 5 Mo."),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      setState(() {
        _enChargement = true;
        _previewOctets = octets;
      });

      await AuthService.instance.uploaderPhotoProfil(octets, nom: nom);

      if (mounted) {
        setState(() {
          _enChargement = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo de profil mise à jour avec succès !"),
            backgroundColor: Color(0xFF166534),
          ),
        );
        widget.onPhotoChangee?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enChargement = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la mise à jour de la photo : $e"),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _supprimerPhoto() async {
    try {
      setState(() {
        _enChargement = true;
      });
      await AuthService.instance.supprimerPhotoProfil();
      if (mounted) {
        setState(() {
          _enChargement = false;
          _previewOctets = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo de profil supprimée."),
            backgroundColor: Color(0xFF166534),
          ),
        );
        widget.onPhotoChangee?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enChargement = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la suppression : $e"),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double badgeSize = (widget.taille * 0.32).clamp(24.0, 32.0);
    final String? url = widget.photoUrl;
    final bool aPhotoServeur = url != null && url.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Cercle principal avatar
        GestureDetector(
          onTap: widget.editable ? _ouvrirSelecteurPhoto : null,
          child: Container(
            width: widget.taille,
            height: widget.taille,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEBDDCE),
              border: Border.all(color: Colors.white, width: 3.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1846321E),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _enChargement
                  ? Container(
                      color: const Color(0xFFEBDDCE),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                        ),
                      ),
                    )
                  : _previewOctets != null
                      ? Image.memory(
                          _previewOctets!,
                          fit: BoxFit.cover,
                          width: widget.taille,
                          height: widget.taille,
                        )
                      : aPhotoServeur
                          ? Image.network(
                              ApiConfig.resolutionImageUrl(url),
                              fit: BoxFit.cover,
                              width: widget.taille,
                              height: widget.taille,
                              errorBuilder: (_, __, ___) => CustomPaint(
                                painter: widget.customPainterDefaut,
                                child: const SizedBox.expand(),
                              ),
                            )
                          : CustomPaint(
                              painter: widget.customPainterDefaut,
                              child: const SizedBox.expand(),
                            ),
            ),
          ),
        ),

        // Bouton badge caméra d'édition en bas à droite
        if (widget.editable)
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: _ouvrirSelecteurPhoto,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x28000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: badgeSize * 0.55,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
