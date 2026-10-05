import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran de création d'une campagne d'Achat Groupé par le Grossiste
class CreerGroupeGrossisteScreen extends StatefulWidget {
  const CreerGroupeGrossisteScreen({super.key});

  @override
  State<CreerGroupeGrossisteScreen> createState() => _CreerGroupeGrossisteScreenState();
}

class _CreerGroupeGrossisteScreenState extends State<CreerGroupeGrossisteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController(text: "Groupe Import Bazin Super Riche 10m");
  final _objectifPiecesController = TextEditingController(text: "50");
  final _prixUnitaireGroupeController = TextEditingController(text: "42000");
  final _prixPublicController = TextEditingController(text: "65000");
  final _dureeJoursController = TextEditingController(text: "7");

  String _selectedProduit = "Bazin Riche Getzner Authentique";
  String _selectedTransitaire = "Touré Transit (Maritime - 25j)";

  @override
  void dispose() {
    _titreController.dispose();
    _objectifPiecesController.dispose();
    _prixUnitaireGroupeController.dispose();
    _prixPublicController.dispose();
    _dureeJoursController.dispose();
    super.dispose();
  }

  void _lancerCampagne() {
    if (_formKey.currentState?.validate() ?? false) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
              SizedBox(width: 10),
              Text("Campagne Lancée !", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Le groupe d'achat pour \"${_titreController.text}\" est désormais visible par tous les commerçants de Bamako !",
                style: const TextStyle(fontSize: 13.5, color: AppTheme.textDark),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildRow("Objectif :", "${_objectifPiecesController.text} pièces"),
                    _buildRow("Prix de groupe :", "${_prixUnitaireGroupeController.text} FCFA"),
                    _buildRow("Économie commerçant :", "-35%"),
                    _buildRow("Durée :", "${_dureeJoursController.text} jours"),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Fermer et voir mes groupes"),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Créer un Groupe d'Achat", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C241E), Color(0xFF45362C)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.groups_rounded, color: AppTheme.secondary, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Réunissez des commerçants pour atteindre votre volume de gros.",
                        style: TextStyle(color: Colors.white, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Produit associé
              const Text("1. Sélectionner l'article du catalogue", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5DDD5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedProduit,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: "Bazin Riche Getzner Authentique",
                        child: Text("Bazin Riche Getzner Authentique"),
                      ),
                      DropdownMenuItem(
                        value: "Sneakers Chunky Sport Fashion",
                        child: Text("Sneakers Chunky Sport Fashion"),
                      ),
                      DropdownMenuItem(
                        value: "Robes Abayas Brodées Dubaï",
                        child: Text("Robes Abayas Brodées Dubaï"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProduit = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Titre de la campagne
              const Text("2. Titre de l'offre groupée", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titreController,
                decoration: InputDecoration(
                  hintText: "Ex : Grand arrivage Bazin - MOQ 50",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.isEmpty ? "Champ requis" : null,
              ),

              const SizedBox(height: 18),

              // Objectif & Durée
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Objectif (Pièces)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _objectifPiecesController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: "pcs",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Durée limite (Jours)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _dureeJoursController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: "jours",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Prix public vs Prix Groupe
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Prix Unitaire Groupe", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _prixUnitaireGroupeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: "F",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Prix Détail Normal", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _prixPublicController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: "F",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Transitaire recommandé
              const Text("3. Transitaire logistique assigné", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5DDD5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTransitaire,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: "Touré Transit (Maritime - 25j)",
                        child: Text("Touré Transit (Maritime - 25j)"),
                      ),
                      DropdownMenuItem(
                        value: "Dogo Cargo Express (Aérien - 7j)",
                        child: Text("Dogo Cargo Express (Aérien - 7j)"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTransitaire = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Bouton Lancer
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _lancerCampagne,
                  icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white),
                  label: const Text(
                    "Publier & Ouvrir le Groupe",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
