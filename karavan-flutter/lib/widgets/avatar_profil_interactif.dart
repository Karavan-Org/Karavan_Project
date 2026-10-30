import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/camera/camera_helper.dart';
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
    final theme = Theme.of(context);
    final String? choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.rayonXL)),
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
                    color: Theme.of(ctx).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Photo de profil",
                style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 4),
              const Text(
                "Personnalisez votre photo de profil visible par vos partenaires et l'administrateur.",
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_camera_rounded, color: Theme.of(ctx).colorScheme.primary),
                ),
                title: const Text("Prendre une photo", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: const Text("Caméra ou webcam en direct", style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library_rounded, color: Theme.of(ctx).colorScheme.primary),
                ),
                title: const Text("Choisir dans la galerie", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: const Text("Importer une image enregistrée", style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'galerie'),
              ),
              if ((widget.photoUrl != null && widget.photoUrl!.isNotEmpty) || _previewOctets != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
                  ),
                  title: Text("Supprimer la photo", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Theme.of(ctx).colorScheme.error)),
                  subtitle: const Text("Revenir à l'avatar par défaut", style: TextStyle(fontSize: 12)),
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
                SnackBar(
                  content: const Text("Accès à la caméra refusé. Vous pouvez choisir une image dans la galerie."),
                  backgroundColor: Theme.of(context).colorScheme.error,
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
          SnackBar(
            content: const Text("L'image est trop volumineuse. La taille maximale est de 5 Mo."),
            backgroundColor: Theme.of(context).colorScheme.error,
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
          SnackBar(
            content: const Text("Photo de profil mise à jour avec succès !"),
            backgroundColor: AppTheme.couleurSucces(context),
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
          SnackBar(
            content: const Text("Photo de profil supprimée."),
            backgroundColor: AppTheme.couleurSucces(context),
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              color: colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.surface, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.09),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _enChargement
                  ? Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.primary),
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
                              cacheWidth: (widget.taille * MediaQuery.devicePixelRatioOf(context)).ceil(),
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
                  color: colorScheme.primary,
                  border: Border.all(color: colorScheme.surface, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.16),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: badgeSize * 0.55,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
