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
  final _nomController = TextEditingController(text: "Sneakers Sport Pro V2");
  final _prixController = TextEditingController(text: "12500");
  final _descController = TextEditingController(
    text: "Chaussures de sport respirantes, semelle amortissante haute résistance.",
  );

  String _categorie = "Chaussures";
  String _selectedImage = "assets/images/008_nike-vomero-plus-2-1067x800-removebg-preview.png";

  final List<Map<String, dynamic>> _variantes = [
    {"taille": "40", "couleur": "Noir / Blanc", "stock": 150},
    {"taille": "41", "couleur": "Noir / Blanc", "stock": 200},
    {"taille": "42", "couleur": "Noir / Blanc", "stock": 250},
    {"taille": "43", "couleur": "Noir / Blanc", "stock": 180},
    {"taille": "44", "couleur": "Gris / Bleu", "stock": 100},
  ];

  final List<String> _photosDisponibles = [
    "assets/images/008_nike-vomero-plus-2-1067x800-removebg-preview.png",
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
              const Text(
                "Photos du produit (depuis vos assets)",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photosDisponibles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final photo = _photosDisponibles[index];
                    final isSelected = photo == _selectedImage;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedImage = photo),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : const Color(0xFFE2D8CF),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
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
                            fontSize: 11,
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
                        style: const TextStyle(color: AppTheme.success, fontSize: 11),
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
