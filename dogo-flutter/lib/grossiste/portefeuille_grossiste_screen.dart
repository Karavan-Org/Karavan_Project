import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/zone_portefeuille_neumorphic.dart';

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
            // --- ZONE PORTEFEUILLE NEUMORPHIQUE SOFT 3D (Style Maquette) ---
            ZonePortefeuilleNeumorphic(
              titre: "Portefeuille Grossiste",
              sousTitre: "Ventes encaissées & séquestres sécurisés",
              montantSolde: "$_soldeDisponible FCFA",
              infoSequestre: "Séquestre en cours : $_soldeEnCoursSequestre F (Lots en transit)",
              iconeInfo: Icons.lock_clock_rounded,
              texteBoutonAction: "Demander un Virement SWIFT",
              onTapAction: _demanderVirement,
              couleurBouton: const [
                Color(0xFF3E2B1F),
                Color(0xFF2A1C14),
                Color(0xFF1B110B),
              ],
              couleurEmbleme: const [
                Color(0xFFFFFFFF),
                Color(0xFFE5A100),
                Color(0xFF7D4F27),
              ],
              titreSquirclesRapides: "GESTION BANCAIRE",
              squirclesRapides: [
                ZonePortefeuilleNeumorphic.buildSquircleRapide(
                  label: "Virement",
                  onTap: _demanderVirement,
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Color(0xFF9E6738),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 24),
                ZonePortefeuilleNeumorphic.buildSquircleRapide(
                  label: "Relevé",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Téléchargement du relevé de compte en cours..."),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF9E6738),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 24),
                ZonePortefeuilleNeumorphic.buildSquircleRapide(
                  label: "Comptes",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Comptes bancaires internationaux configurés"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF9E6738),
                    size: 22,
                  ),
                ),
              ],
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
