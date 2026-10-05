import 'package:flutter/material.dart';
import '../commercant/commercant_main_nav.dart';
import '../courtier/courtier_main_nav.dart';

/// Écran des Paramètres du Grossiste
class ParametresGrossisteScreen extends StatefulWidget {
  const ParametresGrossisteScreen({super.key});

  @override
  State<ParametresGrossisteScreen> createState() => _ParametresGrossisteScreenState();
}

class _ParametresGrossisteScreenState extends State<ParametresGrossisteScreen> {
  String _devise = "FCFA";
  bool _notifGroupes = true;
  bool _notifCommandes = true;

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
          "Paramètres Entreprise",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("GÉNÉRAL & FACTURATION", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF8C7E74), letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded, color: Color(0xFF9E6738)),
                  title: const Text("Devise de référence", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _devise,
                      items: const [
                        DropdownMenuItem(value: "FCFA", child: Text("FCFA (XOF)")),
                        DropdownMenuItem(value: "USD", child: Text("USD (\$)")),
                        DropdownMenuItem(value: "CNY", child: Text("CNY (¥)")),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _devise = val);
                      },
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                ListTile(
                  leading: const Icon(Icons.warehouse_rounded, color: Color(0xFF9E6738)),
                  title: const Text("Adresses des Entrepôts Usine", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Wenzhou Industrial Park, Block 4B, Chine", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFC7B8AA)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Édition des coordonnées de l'entrepôt de ramassage transitaire")),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text("ALERTES COMMANDES & GROUPES", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF8C7E74), letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: const Color(0xFF9E6738),
                  activeTrackColor: const Color(0xFF9E6738).withValues(alpha: 0.4),
                  title: const Text("Alertes Groupes Atteints (RG-18)", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Notification immédiate pour confirmer le stock sous 24h", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  value: _notifGroupes,
                  onChanged: (val) => setState(() => _notifGroupes = val),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                SwitchListTile(
                  activeThumbColor: const Color(0xFF9E6738),
                  activeTrackColor: const Color(0xFF9E6738).withValues(alpha: 0.4),
                  title: const Text("Bordereaux Transit & Ramassage", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Confirmation de prise en charge par les courtiers", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  value: _notifCommandes,
                  onChanged: (val) => setState(() => _notifCommandes = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section Développeur / Commutation de rôle
          const Text("ESPACE DÉMONSTRATION & RÔLES", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF8C7E74), letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tester les autres espaces (Navigation & FAB) :",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF2C241E)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CommercantMainNav()),
                          );
                        },
                        icon: const Icon(Icons.store, size: 16),
                        label: const Text("Commerçant", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9E6738),
                          side: const BorderSide(color: Color(0xFF9E6738)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CourtierMainNav()),
                          );
                        },
                        icon: const Icon(Icons.local_shipping_rounded, size: 16),
                        label: const Text("Courtier", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
