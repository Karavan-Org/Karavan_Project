import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import '../services/catalogue_api_service.dart';
import '../theme/app_theme.dart';
import 'camera_helper.dart';

/// Formulaire d'ajout de produit pour le Grossiste avec capture Caméra, sélection Galerie,
/// aperçu temps réel, validation taille/format, et upload multipart vers Spring Boot.
class AjouterProduitScreen extends StatefulWidget {
  const AjouterProduitScreen({super.key});

  @override
  State<AjouterProduitScreen> createState() => _AjouterProduitScreenState();
}

class _AjouterProduitScreenState extends State<AjouterProduitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prixController = TextEditingController();
  final _descController = TextEditingController();
  final _paysOrigineController = TextEditingController(text: "Mali");
  final ImagePicker _picker = ImagePicker();

  static const int _tailleMaxOctets = 5 * 1024 * 1024; // 5 Mo

  // Catégories
  int _selectedCategorieId = 1;
  List<Map<String, dynamic>> _categories = [
    {"id": 1, "nom": "Chaussures"},
    {"id": 2, "nom": "Vêtements"},
    {"id": 3, "nom": "Électronique"},
    {"id": 4, "nom": "Maison"},
  ];

  // Gestion de la photo
  Uint8List? _uploadedImageBytes;
  String? _uploadedImageName;
  int _uploadedImageTaille = 0;
  String _photoSourceLabel = "Aucune photo";

  // Modèles par défaut si pas de photo téléchargée
  String _selectedImagePredefinie = "assets/images/Nike_Joyride-removebg-preview.png";
  final List<String> _photosDisponibles = [
    "assets/images/Nike_Joyride-removebg-preview.png",
    "assets/images/black-dress-boots-2-mob.jpg",
    "assets/images/sandales-talon-rouge.jpg",
    "assets/images/Montre-Homme-Quartz-Acier-Inoxydable-Cadran-Rond-Affichage-Analogique-Et-Num-rique-Boucle-Pliante-Simple-Cristal-Renforc-Nihaojewelry-France.webp",
  ];

  // Variantes
  final List<Map<String, dynamic>> _variantes = [
    {"sku": "SKU-STD-01", "taille": "Unique", "couleur": "Standard", "stock": 100},
  ];

  // États de soumission
  bool _isSubmitting = false;
  String _submissionMessage = "";

  @override
  void initState() {
    super.initState();
    _chargerCategories();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prixController.dispose();
    _descController.dispose();
    _paysOrigineController.dispose();
    super.dispose();
  }

  Future<void> _chargerCategories() async {
    try {
      final cats = await CatalogueApiService.instance.categories();
      if (cats.isNotEmpty && mounted) {
        setState(() {
          _categories = cats.map((c) => {
            "id": (c['id'] as num).toInt(),
            "nom": c['nom'] ?? 'Catégorie',
          }).toList();
          _selectedCategorieId = _categories.first['id'] as int;
        });
      }
    } catch (_) {
      // Conserve les catégories par défaut
    }
  }

  void _ajouterVariante() {
    setState(() {
      final index = _variantes.length + 1;
      _variantes.add({
        "sku": "SKU-VAR-$index",
        "taille": "42",
        "couleur": "Noir",
        "stock": 50,
      });
    });
  }

  // ==========================================
  // GESTION PERMISSION ET CAPTURE CAMÉRA
  // ==========================================
  Future<void> _prendrePhoto() async {
    try {
      // 1. Sur le Web : utilisation de WebRTC direct avec aperçu en temps réel
      if (kIsWeb) {
        final bytes = await ouvrirCameraWeb(context);
        if (bytes != null) {
          if (bytes.lengthInBytes > _tailleMaxOctets) {
            _afficherAlerteTaille(bytes.lengthInBytes);
            return;
          }
          setState(() {
            _uploadedImageBytes = bytes;
            _uploadedImageName = "photo_camera_${DateTime.now().millisecondsSinceEpoch}.jpg";
            _uploadedImageTaille = bytes.lengthInBytes;
            _photoSourceLabel = "📷 Caméra (Webcam)";
          });
          _afficherSucces("Photo prise avec succès depuis la caméra !");
        }
        return;
      }

      // 2. Sur Mobile natif (Android / iOS) : Vérification stricte des permissions au clic
      final statut = await Permission.camera.status;

      if (statut.isPermanentlyDenied) {
        _afficherDialogueParametres();
        return;
      }

      if (!statut.isGranted) {
        final demande = await Permission.camera.request();
        if (demande.isPermanentlyDenied) {
          _afficherDialogueParametres();
          return;
        }
        if (!demande.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Accès à la caméra refusé. Vous pouvez réessayer ou choisir depuis la galerie."),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      // Permission accordée : ouverture de la caméra native
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        final taille = await photo.length();
        if (taille > _tailleMaxOctets) {
          _afficherAlerteTaille(taille);
          return;
        }

        final bytes = await photo.readAsBytes();
        setState(() {
          _uploadedImageBytes = bytes;
          _uploadedImageName = photo.name.isNotEmpty ? photo.name : "photo_${DateTime.now().millisecondsSinceEpoch}.jpg";
          _uploadedImageTaille = taille;
          _photoSourceLabel = "📷 Caméra smartphone";
        });
        _afficherSucces("Photo enregistrée avec succès !");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible d'accéder à la caméra : ${e.toString()}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================
  // SÉLECTION DEPUIS LA GALERIE
  // ==========================================
  Future<void> _selectionnerDepuisGalerie() async {
    try {
      if (kIsWeb) {
        // Sur Web : FilePicker pour importer depuis les fichiers du PC
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );

        if (files.isNotEmpty) {
          final file = files.first;
          final bytes = await file.readAsBytes();
          if (bytes.lengthInBytes > _tailleMaxOctets) {
            _afficherAlerteTaille(bytes.lengthInBytes);
            return;
          }
          setState(() {
            _uploadedImageBytes = bytes;
            _uploadedImageName = file.name;
            _uploadedImageTaille = bytes.lengthInBytes;
            _photoSourceLabel = "🖼️ Galerie PC (${file.name})";
          });
          _afficherSucces("Image importée depuis la galerie avec succès !");
        }
        return;
      }

      // Sur Mobile
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final taille = await image.length();
        if (taille > _tailleMaxOctets) {
          _afficherAlerteTaille(taille);
          return;
        }

        final bytes = await image.readAsBytes();
        setState(() {
          _uploadedImageBytes = bytes;
          _uploadedImageName = image.name.isNotEmpty ? image.name : "galerie_${DateTime.now().millisecondsSinceEpoch}.jpg";
          _uploadedImageTaille = taille;
          _photoSourceLabel = "🖼️ Galerie photo";
        });
        _afficherSucces("Image sélectionnée depuis la galerie !");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection : ${e.toString()}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================
  // GESTION SUPPRESSION ET REMPLACEMENT
  // ==========================================
  void _supprimerPhoto() {
    setState(() {
      _uploadedImageBytes = null;
      _uploadedImageName = null;
      _uploadedImageTaille = 0;
      _photoSourceLabel = "Aucune photo";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Photo supprimée"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _afficherAlerteTaille(int tailleOctets) {
    final mo = (tailleOctets / (1024 * 1024)).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("Image trop volumineuse"),
          ],
        ),
        content: Text("La photo sélectionnée fait $mo Mo. La limite autorisée est de 5 Mo pour garantir des temps de chargement rapides."),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text("Compris"),
          ),
        ],
      ),
    );
  }

  void _afficherDialogueParametres() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.camera_alt_rounded, color: AppTheme.primary, size: 28),
            SizedBox(width: 10),
            Text("Autorisation requise"),
          ],
        ),
        content: const Text(
          "L'accès à l'appareil photo est actuellement bloqué dans les paramètres de votre appareil.\n\nVeuillez ouvrir les réglages pour activer la caméra afin de photographier vos articles.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text("Ouvrir les paramètres"),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _ouvrirSelectionPhotoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            const SizedBox(height: 18),
            const Text(
              "Ajouter une photo du produit",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 4),
            const Text(
              "Prenez une photo en direct ou choisissez depuis votre galerie",
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary, size: 26),
              ),
              title: const Text("Prendre une photo (Caméra)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              subtitle: const Text("Ouvrir l'appareil photo du téléphone ou webcam", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _prendrePhoto();
              },
            ),
            const Divider(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppTheme.secondary, size: 26),
              ),
              title: const Text("Choisir depuis la galerie", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              subtitle: const Text("Sélectionner une photo déjà enregistrée", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _selectionnerDepuisGalerie();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SOUMISSION DU FORMULAIRE ET ENVOI MULTIPART
  // ==========================================
  Future<void> _soumettreProduit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_variantes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez définir au moins une variante ou taille de stock."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionMessage = "Préparation des données...";
    });

    try {
      String? photoUrlFinale;

      // Étape 1 : Si le grossiste a capturé ou importé une photo, on l'envoie en multipart
      if (_uploadedImageBytes != null) {
        setState(() {
          _submissionMessage = "Téléversement sécurisé de la photo...";
        });

        photoUrlFinale = await CatalogueApiService.instance.uploaderPhotoProduit(
          bytes: _uploadedImageBytes!,
          nomFichier: _uploadedImageName ?? "produit_${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
      }

      // Étape 2 : Enregistrement du produit avec son URL de photo
      setState(() {
        _submissionMessage = "Enregistrement dans votre catalogue...";
      });

      final variantesPayload = _variantes.map((v) => {
        "sku": v['sku'] ?? "SKU-${DateTime.now().millisecondsSinceEpoch}",
        "taille": v['taille'] ?? "Unique",
        "couleur": v['couleur'] ?? "Standard",
        "qteDisponible": (v['stock'] is int) ? v['stock'] : int.tryParse(v['stock'].toString()) ?? 10,
      }).toList();

      await CatalogueApiService.instance.creerProduit(
        categorieId: _selectedCategorieId,
        nom: _nomController.text.trim(),
        description: _descController.text.trim(),
        paysOrigine: _paysOrigineController.text.trim().isNotEmpty ? _paysOrigineController.text.trim() : "Mali",
        photoUrl: photoUrlFinale,
        variantes: variantesPayload,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text("Produit et photo enregistrés avec succès dans votre catalogue !"),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text("Erreur d'enregistrement"),
            ],
          ),
          content: Text("Une erreur est survenue lors de l'envoi vers le serveur : ${e.toString()}"),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text("Fermer"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Ajouter un Produit",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION PHOTOS DU PRODUIT ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Photos du produit (Obligatoire)",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      TextButton.icon(
                        onPressed: () => _ouvrirSelectionPhotoModal(context),
                        icon: const Icon(Icons.add_a_photo, size: 16, color: AppTheme.primary),
                        label: const Text(
                          "Ajouter / Changer",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Deux boutons d'action directs : Caméra et Galerie
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _prendrePhoto,
                          icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          label: const Text(
                            "📷 Prendre photo",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectionnerDepuisGalerie,
                          icon: const Icon(Icons.photo_library_outlined, size: 18, color: AppTheme.primary),
                          label: const Text(
                            "🖼️ Galerie",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Zone d'aperçu de la photo
                  _buildZoneApercuPhoto(),

                  const SizedBox(height: 12),

                  // Modèles pré-définis de secours
                  if (_uploadedImageBytes == null) ...[
                    const Text(
                      "Ou choisir parmi les modèles de base :",
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photosDisponibles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final photo = _photosDisponibles[index];
                          final isSelected = photo == _selectedImagePredefinie;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedImagePredefinie = photo;
                            }),
                            child: Container(
                              width: 70,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primary : const Color(0xFFE2D8CF),
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(photo, fit: BoxFit.contain),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // --- INFORMATIONS DU PRODUIT ---
                  _buildTextField(
                    controller: _nomController,
                    label: "Nom commercial du produit *",
                    icon: Icons.title_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Veuillez renseigner le nom de l'article" : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2D8CF)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedCategorieId,
                              items: _categories.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c['id'] as int,
                                  child: Text(c['nom'] as String, style: const TextStyle(fontSize: 13.5)),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedCategorieId = v);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _prixController,
                          label: "Prix de gros (XOF) *",
                          icon: Icons.payments_rounded,
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || v.trim().isEmpty) ? "Prix requis" : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _paysOrigineController,
                          label: "Pays d'origine",
                          icon: Icons.flag_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _descController,
                    label: "Description détaillée & matière",
                    icon: Icons.description_rounded,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 24),

                  // --- SECTION VARIANTES & STOCKS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Variantes & Stocks de gros",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            "${_variantes.length} variante(s) définie(s)",
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _ajouterVariante,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text("Ajouter"),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEAE2D9)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _variantes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0EAE3)),
                      itemBuilder: (context, index) {
                        final v = _variantes[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.tertiary.withValues(alpha: 0.5),
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                          title: Text(
                            "Taille ${v['taille']} • ${v['couleur']}",
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            "Stock : ${v['stock']} unités • SKU : ${v['sku']}",
                            style: const TextStyle(color: AppTheme.success, fontSize: 11.5),
                          ),
                          trailing: _variantes.length > 1
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() {
                                      _variantes.removeAt(index);
                                    });
                                  },
                                )
                              : null,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- BOUTON DE SOUMISSION ---
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _soumettreProduit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Enregistrer dans mon catalogue",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Overlay de chargement pendant l'upload multipart
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.primary),
                      const SizedBox(height: 18),
                      Text(
                        _submissionMessage,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Veuillez patienter...",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Zone d'aperçu de l'image sélectionnée
  Widget _buildZoneApercuPhoto() {
    final bool aPhotoReelle = _uploadedImageBytes != null;

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2D8CF)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          // Image affichée
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: aPhotoReelle
                  ? Image.memory(
                      _uploadedImageBytes!,
                      fit: BoxFit.contain,
                    )
                  : Image.asset(
                      _selectedImagePredefinie,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_outlined,
                        size: 60,
                        color: AppTheme.primary,
                      ),
                    ),
            ),
          ),

          // Badge source et taille
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: aPhotoReelle ? AppTheme.primary : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    aPhotoReelle ? Icons.check_circle : Icons.info_outline,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    aPhotoReelle
                        ? "$_photoSourceLabel (${(_uploadedImageTaille / 1024).toStringAsFixed(0)} Ko)"
                        : "Modèle prédéfini",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Boutons d'action contextuels sur la photo réelle (Remplacer / Supprimer)
          if (aPhotoReelle)
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 20),
                      tooltip: "Remplacer la photo",
                      onPressed: () => _ouvrirSelectionPhotoModal(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      tooltip: "Supprimer la photo",
                      onPressed: _supprimerPhoto,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2D8CF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2D8CF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }
}
