import 'package:flutter/material.dart';
import '../theme/app_theme.dart';


/// Écran des Paramètres du Courtier (Tarifs au kg, Dépôts relais, Agréments douane, Rôles)
class ParametresCourtierScreen extends StatefulWidget {
  const ParametresCourtierScreen({super.key});

  @override
  State<ParametresCourtierScreen> createState() => _ParametresCourtierScreenState();
}

class _ParametresCourtierScreenState extends State<ParametresCourtierScreen> {
  bool _smsCommercants = true;
  bool _alertesDouanes = true;

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
          "Paramètres Agence Logistique",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF2C241E)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("AGENCE & TARIFICATION", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF8C7E74), letterSpacing: 0.8)),
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
                  leading: const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF9E6738)),
                  title: const Text("Tarifs Fret Aérien & Maritime", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("4 500 F/kg Istanbul • 3 800 F/kg Guangzhou", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFC7B8AA)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Édition de la grille tarifaire au kilo")),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                ListTile(
                  leading: const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF9E6738)),
                  title: const Text("Dépôts & Points Relais Bamako", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Grand Marché Dabanani (Porte 14) & Halles de Bamako", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFC7B8AA)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Point Relais Dabanani (Porte 14) : Ouvert du Lundi au Samedi de 08h à 18h30."),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                const ListTile(
                  leading: Icon(Icons.shield_outlined, color: Color(0xFF9E6738)),
                  title: Text("Agrément Douanes Mali", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: Text("NIF 084192043M • Licence CEMAC/UEMOA", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  trailing: Icon(Icons.verified, color: AppTheme.success, size: 18),
                ),
              ],
            )),
          ),

          const SizedBox(height: 24),

          const Text("ALERTES & COMMUNICATIONS", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF8C7E74), letterSpacing: 0.8)),
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
                  title: const Text("SMS automatiques aux commerçants", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Notification à chaque étape pointée (Douane, Dépôt, Retrait)", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  value: _smsCommercants,
                  onChanged: (val) => setState(() => _smsCommercants = val),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                SwitchListTile(
                  activeThumbColor: const Color(0xFF9E6738),
                  activeTrackColor: const Color(0xFF9E6738).withValues(alpha: 0.4),
                  title: const Text("Alertes Dédouanement DoGo", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text("Notifications de transmission des manifestes", style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74))),
                  value: _alertesDouanes,
                  onChanged: (val) => setState(() => _alertesDouanes = val),
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
                        onPressed: () => Navigator.of(context).pushNamed('/commercant'),
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
                        onPressed: () => Navigator.of(context).pushNamed('/grossiste'),
                        icon: const Icon(Icons.storefront_rounded, size: 16),
                        label: const Text("Grossiste", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
