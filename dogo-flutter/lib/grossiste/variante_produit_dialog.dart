import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Boîte de dialogue moderne permettant au grossiste de saisir ou modifier
/// librement la taille, la couleur, la quantité en stock et le SKU d'une variante.
class VarianteProduitDialog extends StatefulWidget {
  final Map<String, dynamic>? varianteInitiale;

  const VarianteProduitDialog({super.key, this.varianteInitiale});

  @override
  State<VarianteProduitDialog> createState() => _VarianteDialogState();
}

class _VarianteDialogState extends State<VarianteProduitDialog> {
  final _dialogFormKey = GlobalKey<FormState>();
  late final TextEditingController _tailleController;
  late final TextEditingController _couleurController;
  late final TextEditingController _stockController;
  late final TextEditingController _skuController;

  final List<String> _suggestionsTaillesStandard = [
    "Unique",
    "S",
    "M",
    "L",
    "XL",
    "XXL",
  ];

  final List<String> _suggestionsPointures = [
    "38",
    "39",
    "40",
    "41",
    "42",
    "43",
    "44",
    "45",
  ];

  final List<Map<String, dynamic>> _suggestionsCouleurs = [
    {"nom": "Noir", "color": Colors.black},
    {"nom": "Blanc", "color": Colors.white, "border": true},
    {"nom": "Bleu", "color": const Color(0xFF1976D2)},
    {"nom": "Rouge", "color": const Color(0xFFD32F2F)},
    {"nom": "Marron", "color": const Color(0xFF795548)},
    {"nom": "Vert", "color": const Color(0xFF388E3C)},
    {"nom": "Beige", "color": const Color(0xFFD7CCC8)},
    {"nom": "Gris", "color": const Color(0xFF757575)},
    {"nom": "Jaune", "color": const Color(0xFFFBC02D)},
    {"nom": "Orange", "color": const Color(0xFFF57C00)},
    {"nom": "Standard", "color": null},
  ];

  @override
  void initState() {
    super.initState();
    final ini = widget.varianteInitiale;
    _tailleController = TextEditingController(
        text: ini != null ? (ini['taille']?.toString() ?? '') : '');
    _couleurController = TextEditingController(
        text: ini != null ? (ini['couleur']?.toString() ?? '') : '');
    _stockController = TextEditingController(
        text: ini != null ? (ini['stock']?.toString() ?? '50') : '50');
    _skuController = TextEditingController(
        text: ini != null ? (ini['sku']?.toString() ?? '') : '');
  }

  @override
  void dispose() {
    _tailleController.dispose();
    _couleurController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  void _ajusterStock(int delta) {
    final actuel = int.tryParse(_stockController.text.trim()) ?? 0;
    final nouveau = (actuel + delta).clamp(1, 999999);
    setState(() {
      _stockController.text = nouveau.toString();
    });
  }

  void _definirStock(int valeur) {
    setState(() {
      _stockController.text = valeur.toString();
    });
  }

  void _validerEtFermer() {
    if (!_dialogFormKey.currentState!.validate()) {
      return;
    }
    final stockVal = int.tryParse(_stockController.text.trim()) ?? 1;
    final tailleVal = _tailleController.text.trim();
    final couleurVal = _couleurController.text.trim();
    final skuVal = _skuController.text.trim();

    Navigator.pop(context, {
      "taille": tailleVal,
      "couleur": couleurVal,
      "stock": stockVal,
      "sku": skuVal,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.varianteInitiale != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.style_rounded,
                          color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? "Modifier la variante"
                                : "Ajouter une variante",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            isEditing
                                ? "Ajustez la taille, la couleur et le stock"
                                : "Définissez la taille, la couleur et la quantité en stock",
                            style: const TextStyle(
                                fontSize: 12.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "Fermer",
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppTheme.bordure),
                const SizedBox(height: 18),

                // 1. CHAMP TAILLE / POINTURE
                const Text(
                  "Taille ou Pointure *",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tailleController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Ex : 42, L, XL, 38, Unique, 500g...",
                    prefixIcon: const Icon(Icons.straighten_rounded,
                        color: AppTheme.primary, size: 20),
                    filled: true,
                    fillColor: AppTheme.creme,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: AppTheme.couleurBordure(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: AppTheme.couleurBordure(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Veuillez renseigner une taille ou dimension";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Suggestions rapides de taille
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._suggestionsTaillesStandard.map((t) {
                      final selected =
                          _tailleController.text.trim().toLowerCase() ==
                              t.toLowerCase();
                      return ChoiceChip(
                        label: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        selected: selected,
                        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                        backgroundColor: AppTheme.surfaceDouce,
                        labelStyle: TextStyle(
                            color: selected
                                ? AppTheme.primaryDark
                                : AppTheme.textPrimary),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() {
                            _tailleController.text = t;
                          });
                        },
                      );
                    }),
                    ..._suggestionsPointures.map((p) {
                      final selected = _tailleController.text.trim() == p;
                      return ChoiceChip(
                        label: Text(p,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        selected: selected,
                        selectedColor:
                            AppTheme.secondary.withValues(alpha: 0.25),
                        backgroundColor: AppTheme.surfaceDouce,
                        labelStyle: TextStyle(
                            color: selected
                                ? AppTheme.ocreProfond
                                : AppTheme.textPrimary),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() {
                            _tailleController.text = p;
                          });
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. CHAMP COULEUR / MODÈLE
                const Text(
                  "Couleur ou Modèle *",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _couleurController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Ex : Noir, Blanc, Bleu, Rouge, Doré...",
                    prefixIcon: const Icon(Icons.palette_outlined,
                        color: AppTheme.primary, size: 20),
                    filled: true,
                    fillColor: AppTheme.creme,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: AppTheme.couleurBordure(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: AppTheme.couleurBordure(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Veuillez renseigner une couleur ou déclinaison";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Suggestions rapides de couleurs
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _suggestionsCouleurs.map((c) {
                    final nom = c['nom'] as String;
                    final color = c['color'] as Color?;
                    final selected =
                        _couleurController.text.trim().toLowerCase() ==
                            nom.toLowerCase();
                    return ActionChip(
                      avatar: color != null
                          ? Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: c['border'] == true
                                    ? Border.all(
                                        color: AppTheme.textePale, width: 1)
                                    : null,
                              ),
                            )
                          : null,
                      label: Text(nom,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                      backgroundColor: selected
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : AppTheme.surfaceDouce,
                      labelStyle: TextStyle(
                          color: selected
                              ? AppTheme.primaryDark
                              : AppTheme.textPrimary),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _couleurController.text = nom;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // 3. QUANTITÉ EN STOCK
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Quantité en stock disponible *",
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    Row(
                      children: [
                        _BoutonDeltaStock(
                            label: "+10", onTap: () => _ajusterStock(10)),
                        const SizedBox(width: 4),
                        _BoutonDeltaStock(
                            label: "+50", onTap: () => _ajusterStock(50)),
                        const SizedBox(width: 4),
                        _BoutonDeltaStock(
                            label: "+100", onTap: () => _ajusterStock(100)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDouce,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.bordureForte),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.remove,
                            size: 20, color: AppTheme.primaryDark),
                        onPressed: () => _ajusterStock(-5),
                        tooltip: "-5 unités",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Ex : 50",
                          prefixIcon: const Icon(Icons.inventory_2_outlined,
                              color: AppTheme.primary, size: 20),
                          suffixText: "unités",
                          suffixStyle: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.creme,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: AppTheme.couleurBordure(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: AppTheme.couleurBordure(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return "Stock requis";
                          }
                          final parsed = int.tryParse(v.trim());
                          if (parsed == null || parsed < 1) {
                            return "Minimum 1 unité";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDouce,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.bordureForte),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add,
                            size: 20, color: AppTheme.primaryDark),
                        onPressed: () => _ajusterStock(5),
                        tooltip: "+5 unités",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Raccourcis : ",
                        style: TextStyle(
                            fontSize: 11.5, color: AppTheme.textMuted)),
                    for (final qte in [10, 25, 50, 100, 200]) ...[
                      InkWell(
                        onTap: () => _definirStock(qte),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDouce,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.bordureForte),
                          ),
                          child: Text("$qte",
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),

                // 4. RÉFÉRENCE SKU (OPTIONNEL)
                const Text(
                  "Référence SKU (Optionnel)",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _skuController,
                  decoration: InputDecoration(
                    hintText: "Ex : REF-VAR-42-NOIR",
                    helperText:
                        "Laissez vide pour générer un code unique automatique.",
                    helperStyle: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.qr_code_2_rounded,
                        color: AppTheme.textMuted, size: 20),
                    filled: true,
                    fillColor: AppTheme.creme,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: AppTheme.couleurBordure(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: AppTheme.couleurBordure(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),

                // BOUTONS D'ACTION
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppTheme.bordureForte),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Annuler",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _validerEtFermer,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          isEditing ? "Enregistrer" : "Ajouter la variante",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoutonDeltaStock extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BoutonDeltaStock({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
      ),
    );
  }
}
