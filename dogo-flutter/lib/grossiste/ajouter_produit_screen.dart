import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Formulaire d'ajout de produit pour le Grossiste avec gestion des variantes
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

  String _categorie = "Chaussures";
  String _selectedImage = "assets/images/Nike_Joyride-removebg-preview.png";
  String _photoSourceLabel = "Modèle sélectionné";

  final List<Map<String, dynamic>> _variantes = [];

  final List<String> _photosDisponibles = [
    "assets/images/Nike_Joyride-removebg-preview.png",
    "assets/images/black-dress-boots-2-mob.jpg",
    "assets/images/sandales-talon-rouge.jpg",
    "assets/images/Montre-Homme-Quartz-Acier-Inoxydable-Cadran-Rond-Affichage-Analogique-Et-Num-rique-Boucle-Pliante-Simple-Cristal-Renforc-Nihaojewelry-France.webp",
  ];

  @override
  void dispose() {
    _nomController.dispose();
    _prixController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _ajouterVariante() {
    setState(() {
      _variantes.add({"taille": "45", "couleur": "Blanc", "stock": 50});
    });
  }

  void _prendrePhoto() {
    setState(() {
      _selectedImage = "assets/images/Nike_Joyride.jpg";
      _photoSourceLabel = "Prise de vue Caméra HD";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.white),
            SizedBox(width: 10),
            Text("Photo capturée avec succès depuis l'appareil photo !"),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _importerGalerie() {
    setState(() {
      _selectedImage = "assets/images/black-dress-boots-2-mob.jpg";
      _photoSourceLabel = "Importé depuis la galerie";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.photo_library, color: Colors.white),
            SizedBox(width: 10),
            Text("Photo importée avec succès depuis vos fichiers / galerie !"),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _ouvrirSelectionPhoto(BuildContext context) {
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Ajouter une photo du produit",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              "Photographiez l'article ou importez une image haute définition",
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: AppTheme.primary),
              ),
              title: const Text("Prendre une photo (Caméra)", style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text("Ouvrir l'appareil photo du smartphone/tablette", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _prendrePhoto();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: AppTheme.secondary),
              ),
              title: const Text("Importer depuis la galerie", style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text("Sélectionner depuis la bibliothèque de photos ou vos fichiers", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _importerGalerie();
              },
            ),
          ],
        ),
      ),
    );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SÉLECTION DES PHOTOS DU PRODUIT ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Photos du produit (Obligatoire)",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  TextButton.icon(
                    onPressed: () => _ouvrirSelectionPhoto(context),
                    icon: const Icon(Icons.add_a_photo, size: 16, color: AppTheme.primary),
                    label: const Text(
                      "Options",
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

              // Boutons d'action : Caméra & Galerie
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _prendrePhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppTheme.primary),
                      label: const Text(
                        "Prendre photo",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _importerGalerie,
                      icon: const Icon(Icons.photo_library_outlined, size: 18, color: Colors.white),
                      label: const Text(
                        "Importer galerie",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Aperçu de l'image sélectionnée avec badge de source
              Container(
                height: 170,
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          _selectedImage,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shopping_bag_outlined,
                            size: 60,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _photoSourceLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Vignettes de modèles additionnels
              SizedBox(
                height: 75,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photosDisponibles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final photo = _photosDisponibles[index];
                    final isSelected = photo == _selectedImage;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedImage = photo;
                        _photoSourceLabel = "Modèle #${index + 1}";
                      }),
                      child: Container(
                        width: 75,
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
                          child: Image.asset(
                            photo,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 22),

              // --- INFORMATIONS PRODUIT ---
              _buildTextField(
                controller: _nomController,
                label: "Nom commercial du produit",
                icon: Icons.title_rounded,
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
                        child: DropdownButton<String>(
                          value: _categorie,
                          items: ["Chaussures", "Mode & Robes", "Montres", "Talons", "Maroquinerie"]
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _categorie = v);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _prixController,
                      label: "Prix de gros (XOF)",
                      icon: Icons.payments_rounded,
                      keyboardType: TextInputType.number,
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

              // --- GESTION DES VARIANTES (TAILLE, COULEUR, STOCK) ---
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
                        "${_variantes.length} variantes définies",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _ajouterVariante,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Ajouter"),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
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
                          v['taille'],
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
                        "Disponible : ${v['stock']} unités",
                        style: const TextStyle(color: AppTheme.success, fontSize: 11.5),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _variantes.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              // --- BOUTON DE PUBLICATION ---
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Produit enregistré et disponible pour groupage !"),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  Navigator.pop(context);
                },
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
