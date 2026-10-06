import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran Portefeuille du Grossiste (Ventes encaissées, Séquestres déblocables et Retraits bancaires)
class PortefeuilleGrossisteScreen extends StatefulWidget {
  const PortefeuilleGrossisteScreen({super.key});

  @override
  State<PortefeuilleGrossisteScreen> createState() => _PortefeuilleGrossisteScreenState();
}

class _PortefeuilleGrossisteScreenState extends State<PortefeuilleGrossisteScreen> {
  final int _soldeDisponible = 0;
  final int _soldeEnCoursSequestre = 0;

  final List<Map<String, dynamic>> _transactions = [];

  void _demanderVirement() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          "Demande de Virement",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Transférer vos fonds vers votre compte bancaire ?",
              style: TextStyle(fontSize: 13, color: Color(0xFF5A493B)),
            ),
            SizedBox(height: 12),
            Text(
              "Compte par défaut : Bank of China / Wenzhou Branch (USD/CNY)",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF9E6738)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annuler", style: TextStyle(color: Color(0xFF8C7E74))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Demande de virement SWIFT transmise au service financier DoGo"),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9E6738),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Confirmer le Virement"),
          ),
        ],
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
        title: const Text(
          "Portefeuille Grossiste",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte Solde
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C241E), Color(0xFF4A382A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Color(0x20000000), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Fonds disponibles au virement",
                        style: TextStyle(fontSize: 12, color: Color(0xFFD4C5B9), fontWeight: FontWeight.w600),
                      ),
                      ElevatedButton(
                        onPressed: _demanderVirement,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9E6738),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Virement SWIFT", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$_soldeDisponible FCFA",
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFFD4A373)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Séquestre en cours : $_soldeEnCoursSequestre F (Lots en transit)",
                            style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Transactions & Règlements
            const Text(
              "Historique des règlements",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2C241E)),
            ),
            const SizedBox(height: 12),

            if (_transactions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEFE9E0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      "Aucun règlement récent",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF2C241E)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Vos encaissements et déblocages séquestres s'afficheront ici.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                final bool isEntree = tx["isEntree"] as bool;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEFE9E0)),
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
                          color: isEntree ? const Color(0xFFE8F5E9) : const Color(0xFFFBE9E7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEntree ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isEntree ? AppTheme.success : const Color(0xFFC62828),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx["titre"] as String,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2C241E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tx["detail"] as String,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tx["montant"] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: isEntree ? AppTheme.success : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
