import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran Portefeuille Achats du Commerçant (Frame Figma "Portefeuille Achats")
class PortefeuilleCommercantScreen extends StatefulWidget {
  const PortefeuilleCommercantScreen({super.key});

  @override
  State<PortefeuilleCommercantScreen> createState() => _PortefeuilleCommercantScreenState();
}

class _PortefeuilleCommercantScreenState extends State<PortefeuilleCommercantScreen> {
  int _soldeDisponible = 385000;
  final int _soldeSequestre = 110000;

  final List<Map<String, dynamic>> _mouvements = [
    {
      "titre": "Fret Convoi #TR-BKO-88",
      "description": "Amadou Touré • 3 cartons Bazin - Bloqué sous séquestre",
      "montant": "-45 000 F",
      "isCredit": false,
      "date": "11 sept. 2026",
    },
    {
      "titre": "Recharge Portefeuille",
      "description": "Orange Money (+223 76..) • Réf #OM-992",
      "montant": "+300 000 F",
      "isCredit": true,
      "date": "10 sept. 2026",
    },
    {
      "titre": "Sneakers Runner Pro (10 paires)",
      "description": "Lot Grand Dépôt Mandé Dabanani • Paiement libéré",
      "montant": "-65 000 F",
      "isCredit": false,
      "date": "08 sept. 2026",
    },
    {
      "titre": "Remboursement ajustement poids",
      "description": "Trop-perçu pesée convoi #TR-BKO-84",
      "montant": "+15 000 F",
      "isCredit": true,
      "date": "05 sept. 2026",
    },
  ];

  void _showRechargeModal() {
    final montantController = TextEditingController(text: "50000");
    String selectedOperateur = "Orange Money";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5DDD5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Recharger mon Portefeuille",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                "Créditez votre compte pour valider vos achats groupés instantanément.",
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),
              const Text("Choisir l'opérateur :", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildOperateurChip("Orange Money", selectedOperateur, (op) => setModalState(() => selectedOperateur = op)),
                  const SizedBox(width: 8),
                  _buildOperateurChip("Moov Africa", selectedOperateur, (op) => setModalState(() => selectedOperateur = op)),
                  const SizedBox(width: 8),
                  _buildOperateurChip("Wave", selectedOperateur, (op) => setModalState(() => selectedOperateur = op)),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Montant (FCFA) :", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: montantController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: "FCFA",
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final montant = int.tryParse(montantController.text) ?? 0;
                    if (montant > 0) {
                      setState(() {
                        _soldeDisponible += montant;
                        _mouvements.insert(0, {
                          "titre": "Recharge Portefeuille",
                          "description": "$selectedOperateur (+223 76..) • Instantané",
                          "montant": "+${montantController.text} F",
                          "isCredit": true,
                          "date": "À l'instant",
                        });
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Recharge de ${montantController.text} FCFA effectuée avec succès !"),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7D4F27),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Confirmer la Recharge", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperateurChip(String nom, String selected, ValueChanged<String> onSelect) {
    final isSelected = nom == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(nom),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7D4F27) : const Color(0xFFF7F2EC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF7D4F27) : const Color(0xFFE5DDD5)),
          ),
          child: Text(
            nom,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C241E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Portefeuille Achats",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF2C241E)),
            ),
            Text(
              "Boutique Oumar S. • Grand Marché",
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF9E6738), size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Économies groupées DoGo : Vous avez économisé 145 000 FCFA ce mois-ci !"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CARTE SOLDE CHAMPAGNE/DORÉE FIGMA ---
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF9EAD6), Color(0xFFECD2B3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Color(0x1046321E), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Disponible pour vos commandes",
                        style: TextStyle(fontSize: 12, color: Color(0xFF7A685B), fontWeight: FontWeight.w600),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showRechargeModal,
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: const Text("Recharger", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9E6738),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$_soldeDisponible FCFA",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C241E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF9E6738)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Séquestre : $_soldeSequestre F • Paiement après réception de vos colis",
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF5A493B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // --- RECHARGER RAPIDEMENT VIA MOBILE MONEY ---
            const Text(
              "Recharger rapidement via Mobile Money",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF2C241E)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickMoneyCard("Orange Money", "+223 76 12 34 56", const Color(0xFFFF7900), "OM"),
                const SizedBox(width: 12),
                _buildQuickMoneyCard("Moov Africa", "65 12 34 56", const Color(0xFF005DAA), "MM"),
              ],
            ),

            const SizedBox(height: 26),

            // --- MOUVEMENTS & COMMANDES ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Mouvements & commandes",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2C241E)),
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Filtres : Toutes les transactions et commissions sont affichées."),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF9E6738)),
                  label: const Text(
                    "Filtrer",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9E6738)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Liste des mouvements
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mouvements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final m = _mouvements[index];
                final bool isCredit = m["isCredit"] as bool;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0646321E), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFBE9E7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isCredit ? AppTheme.success : const Color(0xFFC62828),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m["titre"] as String,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2C241E)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              m["description"] as String,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m["montant"] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isCredit ? AppTheme.success : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Note de garantie DoGo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EDE4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: Color(0xFF9E6738)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Votre argent reste protégé jusqu'à la remise du colis.",
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF5A493B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMoneyCard(String operateur, String telephone, Color badgeColor, String code) {
    return Expanded(
      child: GestureDetector(
        onTap: _showRechargeModal,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x0646321E), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: badgeColor,
                    child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    operateur,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2C241E)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                telephone,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
