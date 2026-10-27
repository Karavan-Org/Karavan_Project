import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import '../services/catalogue_api_service.dart';
import '../theme/app_theme.dart';
import 'variante_produit_dialog.dart';
import 'camera_helper.dart';
import 'creer_groupe_grossiste_screen.dart';

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

  // Variantes
  final List<Map<String, dynamic>> _variantes = [
    {"sku": "", "taille": "Unique", "couleur": "Standard", "stock": 50},
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
          _categories = cats
              .map((c) => {
                    "id": (c['id'] as num).toInt(),
                    "nom": c['nom'] ?? 'Catégorie',
                  })
              .toList();
          _selectedCategorieId = _categories.first['id'] as int;
        });
      }
    } catch (_) {
      // Conserve les catégories par défaut
    }
  }

  Future<void> _ouvrirDialogueVariante({int? indexAModifier}) async {
    final Map<String, dynamic>? initiale =
        indexAModifier != null ? _variantes[indexAModifier] : null;
    final resultat = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VarianteProduitDialog(varianteInitiale: initiale),
    );

    if (resultat != null && mounted) {
      setState(() {
        if (indexAModifier != null) {
          _variantes[indexAModifier] = resultat;
        } else {
          _variantes.add(resultat);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            indexAModifier != null
                ? "Variante mise à jour (${resultat['taille']} • ${resultat['couleur']})"
                : "Variante ajoutée (${resultat['taille']} • ${resultat['couleur']})",
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _supprimerVariante(int index) {
    if (index >= 0 && index < _variantes.length) {
      final supprimee = _variantes[index];
      setState(() {
        _variantes.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Variante supprimée (${supprimee['taille']} • ${supprimee['couleur']})"),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _ajouterVariante() {
    _ouvrirDialogueVariante();
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
            _uploadedImageName =
                "photo_camera_${DateTime.now().millisecondsSinceEpoch}.jpg";
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
              content: Text(
                  "Accès à la caméra refusé. Vous pouvez réessayer ou choisir depuis la galerie."),
              backgroundColor: AppTheme.ocreProfond,
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
          _uploadedImageName = photo.name.isNotEmpty
              ? photo.name
              : "photo_${DateTime.now().millisecondsSinceEpoch}.jpg";
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
          backgroundColor: AppTheme.danger,
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
          _uploadedImageName = image.name.isNotEmpty
              ? image.name
              : "galerie_${DateTime.now().millisecondsSinceEpoch}.jpg";
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
          backgroundColor: AppTheme.danger,
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
            Icon(Icons.warning_amber_rounded,
                color: AppTheme.ocreProfond, size: 28),
            SizedBox(width: 10),
            Text("Image trop volumineuse"),
          ],
        ),
        content: Text(
            "La photo sélectionnée fait $mo Mo. La limite autorisée est de 5 Mo pour garantir des temps de chargement rapides."),
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
            child: const Text("Annuler",
                style: TextStyle(color: AppTheme.textMuted)),
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
                  color: AppTheme.bordureForte,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Ajouter une photo du produit",
              style: TextStyle(
                  fontFamily: AppTheme.policeTitre,
                  fontWeight: FontWeight.w800,
                  fontSize: 17),
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
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primary, size: 26),
              ),
              title: const Text("Prendre une photo (Caméra)",
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              subtitle: const Text(
                  "Ouvrir l'appareil photo du téléphone ou webcam",
                  style: TextStyle(fontSize: 12)),
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
                child: const Icon(Icons.photo_library_rounded,
                    color: AppTheme.ocreProfond, size: 26),
              ),
              title: const Text("Choisir depuis la galerie",
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              subtitle: const Text("Sélectionner une photo déjà enregistrée",
                  style: TextStyle(fontSize: 12)),
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
          content: Text(
              "Veuillez définir au moins une variante ou taille de stock."),
          backgroundColor: AppTheme.ocreProfond,
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

        photoUrlFinale =
            await CatalogueApiService.instance.uploaderPhotoProduit(
          bytes: _uploadedImageBytes!,
          nomFichier: _uploadedImageName ??
              "produit_${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
      }

      // Étape 2 : Enregistrement du produit avec son URL de photo
      setState(() {
        _submissionMessage = "Enregistrement dans votre catalogue...";
      });

      // Les SKU : s'il y a un SKU personnalisé renseigné par l'utilisateur, on l'utilise ;
      // sinon on génère des SKU uniques (RG-12) conformes à la plateforme
      final skus = CatalogueApiService.genererSkus(
          _nomController.text, _variantes.length);
      var rang = 0;
      final variantesPayload = _variantes.map((v) {
        final customSku = v['sku']?.toString().trim();
        final skuFinal = (customSku != null &&
                customSku.isNotEmpty &&
                !customSku.startsWith("SKU-STD") &&
                !customSku.startsWith("SKU-VAR"))
            ? customSku
            : skus[rang++];
        return {
          "sku": skuFinal,
          "taille":
              (v['taille'] != null && v['taille'].toString().trim().isNotEmpty)
                  ? v['taille'].toString().trim()
                  : "Unique",
          "couleur": (v['couleur'] != null &&
                  v['couleur'].toString().trim().isNotEmpty)
              ? v['couleur'].toString().trim()
              : "Standard",
          "qteDisponible": (v['stock'] is int)
              ? v['stock']
              : int.tryParse(v['stock'].toString()) ?? 10,
        };
      }).toList();

      final produit = await CatalogueApiService.instance.creerProduit(
        categorieId: _selectedCategorieId,
        nom: _nomController.text.trim(),
        description: _descController.text.trim(),
        paysOrigine: _paysOrigineController.text.trim().isNotEmpty
            ? _paysOrigineController.text.trim()
            : "Mali",
        photoUrl: photoUrlFinale,
        prixGros: num.tryParse(
            _prixController.text.trim().replaceAll(RegExp(r'[\s ]'), '')),
        variantes: variantesPayload,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      // Le prix de gros et le stock saisis pré-remplissent le groupe d'achat : on propose de le lancer tout de suite
      final stock = CatalogueApiService.stockTotal(produit);
      final lancer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          icon: const Icon(Icons.check_circle_rounded,
              color: AppTheme.oliveProfond, size: 46),
          title: const Text("Produit ajouté !",
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            "« ${produit['nom'] ?? ''} » est dans votre catalogue.\n\n"
            "Lancer maintenant son groupe d'achat ? Votre prix de gros et votre stock ($stock pcs) "
            "sont déjà repris : il ne reste qu'à confirmer.",
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Plus tard")),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.group_add_rounded, size: 18),
              label: const Text("Créer le groupe"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (lancer == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => CreerGroupeGrossisteScreen(produit: produit)),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.danger, size: 28),
              SizedBox(width: 10),
              Text("Erreur d'enregistrement"),
            ],
          ),
          content: Text(
              "Une erreur est survenue lors de l'envoi vers le serveur : ${e.toString()}"),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text("Fermer"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalStock = _variantes.fold<int>(
      0,
      (sum, v) =>
          sum +
          ((v['stock'] is int)
              ? (v['stock'] as int)
              : int.tryParse(v['stock'].toString()) ?? 0),
    );

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: AppTheme.couleurTexte(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Ajouter un Produit",
          style: TextStyle(
              fontFamily: AppTheme.policeTitre,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.couleurTexte(context)),
        ),
        backgroundColor: AppTheme.couleurCarte(context),
        foregroundColor: AppTheme.couleurTexte(context),
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
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      TextButton.icon(
                        onPressed: () => _ouvrirSelectionPhotoModal(context),
                        icon: const Icon(Icons.add_a_photo,
                            size: 16, color: AppTheme.primary),
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
                          icon: const Icon(Icons.camera_alt_rounded,
                              size: 18, color: Colors.white),
                          label: const Text(
                            "📷 Prendre photo",
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectionnerDepuisGalerie,
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 18, color: AppTheme.primary),
                          label: const Text(
                            "🖼️ Galerie",
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Zone d'aperçu de la photo
                  _buildZoneApercuPhoto(),

                  const SizedBox(height: 12),

                  const SizedBox(height: 22),

                  // --- INFORMATIONS DU PRODUIT ---
                  _buildTextField(
                    controller: _nomController,
                    label: "Nom commercial du produit *",
                    icon: Icons.title_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "Veuillez renseigner le nom de l'article"
                        : null,
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
                            border: Border.all(color: AppTheme.bordureForte),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedCategorieId,
                              items: _categories.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c['id'] as int,
                                  child: Text(c['nom'] as String,
                                      style: const TextStyle(fontSize: 13.5)),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedCategorieId = v);
                                }
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
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Prix requis"
                              : null,
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
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            _variantes.isEmpty
                                ? "Aucune variante définie"
                                : "${_variantes.length} variante(s) • Total : $totalStock unités",
                            style: TextStyle(
                              fontSize: 12,
                              color: _variantes.isEmpty
                                  ? AppTheme.ocreProfond
                                  : AppTheme.textMuted,
                              fontWeight: _variantes.isEmpty
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _ajouterVariante,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text("Ajouter"),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_variantes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.bordure),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 36,
                              color: AppTheme.primary.withValues(alpha: 0.7)),
                          const SizedBox(height: 8),
                          const Text(
                            "Aucune variante définie",
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Renseignez au moins une taille, couleur et quantité en stock.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _ouvrirDialogueVariante(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Créer une première variante"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.bordure),
                      ),
                      child: Material(
                          type: MaterialType.transparency,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _variantes.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: AppTheme.bordure),
                                itemBuilder: (context, index) {
                                  final v = _variantes[index];
                                  return ListTile(
                                    dense: true,
                                    onTap: () => _ouvrirDialogueVariante(
                                        indexAModifier: index),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 2),
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.tertiary
                                          .withValues(alpha: 0.5),
                                      child: Text(
                                        "${index + 1}",
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryDark,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            "Taille : ${v['taille']}",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceDouce,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            "${v['couleur']}",
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppTheme.terreDouce,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.inventory_2_outlined,
                                              size: 13,
                                              color: AppTheme.oliveProfond),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Stock : ${v['stock']} unités",
                                            style: const TextStyle(
                                                color: AppTheme.oliveProfond,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11.5),
                                          ),
                                          if (v['sku'] != null &&
                                              v['sku']
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                "• ${v['sku']}",
                                                style: const TextStyle(
                                                    color: AppTheme.textMuted,
                                                    fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18,
                                              color: AppTheme.primary),
                                          tooltip: "Modifier cette variante",
                                          onPressed: () =>
                                              _ouvrirDialogueVariante(
                                                  indexAModifier: index),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 18,
                                              color: AppTheme.danger),
                                          tooltip: "Supprimer",
                                          onPressed: () =>
                                              _supprimerVariante(index),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1, color: AppTheme.bordure),
                              InkWell(
                                onTap: () => _ouvrirDialogueVariante(),
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(20)),
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 11),
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.creme,
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(20)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add,
                                          size: 16, color: AppTheme.primary),
                                      SizedBox(width: 6),
                                      Text(
                                        "Ajouter une autre variante",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )),
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
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.olive),
                      const SizedBox(height: 18),
                      Text(
                        _submissionMessage,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Veuillez patienter...",
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
        border: Border.all(color: AppTheme.bordureForte),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
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
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 48, color: AppTheme.primary),
                        SizedBox(height: 8),
                        Text(
                          "Aucune photo : prenez-en une ou importez-la",
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
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
                color: aPhotoReelle ? AppTheme.primary : AppTheme.terreDouce,
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
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppTheme.primary, size: 20),
                      tooltip: "Remplacer la photo",
                      onPressed: () => _ouvrirSelectionPhotoModal(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppTheme.danger, size: 20),
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
        fillColor: AppTheme.couleurCarte(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.couleurBordure(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.couleurBordure(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }
}
