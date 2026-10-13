import 'package:flutter/material.dart';
import 'code_retrait_commercant_screen.dart';

/// Écran des Paramètres du Commerçant (Langues, PIN, Notifications, Sécurité)
class ParametresCommercantScreen extends StatefulWidget {
  const ParametresCommercantScreen({super.key});

  @override
  State<ParametresCommercantScreen> createState() => _ParametresCommercantScreenState();
}

class _ParametresCommercantScreenState extends State<ParametresCommercantScreen> {
  String _langue = "Français";
  bool _smsNotif = true;
  bool _pushNotif = true;

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
          "Paramètres",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section Préférences générales
          const Text("GÉNÉRAL", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF8C7E74), letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Material(type: MaterialType.transparency, borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias, child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded, color: Color(0xFF9E6738)),
                  title: const Text("Langue d'affichage", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _langue,
                      items: const [
                        DropdownMenuItem(value: "Français", child: Text("Français 🇲🇱")),
                        DropdownMenuItem(value: "Bambara", child: Text("Bamanankan")),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _langue = val);
                      },
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                ListTile(
                  leading: const Icon(Icons.pin_rounded, color: Color(0xFF9E6738)),
                  title: const Text("Code PIN de retrait", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Gestion et régénération du code PIN 4 chiffres", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFC7B8AA)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CodeRetraitCommercantScreen()),
                    );
                  },
                ),
              ],
            )),
          ),

          const SizedBox(height: 24),

          // Section Notifications
          const Text("ALERTES & NOTIFICATIONS", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF8C7E74), letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Material(type: MaterialType.transparency, borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias, child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: const Color(0xFF9E6738),
                  activeTrackColor: const Color(0xFF9E6738).withValues(alpha: 0.4),
                  title: const Text("Alertes SMS", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Réception des alertes convois & dédouanement", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  value: _smsNotif,
                  onChanged: (val) => setState(() => _smsNotif = val),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                SwitchListTile(
                  activeThumbColor: const Color(0xFF9E6738),
                  activeTrackColor: const Color(0xFF9E6738).withValues(alpha: 0.4),
                  title: const Text("Notifications Push", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Nouveaux groupes d'achats lancés par les grossistes", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  value: _pushNotif,
                  onChanged: (val) => setState(() => _pushNotif = val),
                ),
              ],
            )),
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
                        onPressed: () => Navigator.of(context).pushNamed('/grossiste'),
                        icon: const Icon(Icons.storefront_rounded, size: 16),
                        label: const Text("Grossiste", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                        onPressed: () => Navigator.of(context).pushNamed('/courtier'),
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
