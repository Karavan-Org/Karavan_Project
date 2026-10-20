import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/changer_mot_de_passe_dialog.dart';
import '../services/theme_service.dart';

/// Écran des Paramètres du Courtier (Tarifs au kg, Dépôts relais, Agréments douane, Rôles)
class ParametresCourtierScreen extends StatefulWidget {
  const ParametresCourtierScreen({super.key});

  @override
  State<ParametresCourtierScreen> createState() =>
      _ParametresCourtierScreenState();
}

class _ParametresCourtierScreenState extends State<ParametresCourtierScreen> {
  bool _smsCommercants = true;
  bool _alertesDouanes = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Paramètres Agence Logistique",
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppTheme.couleurTexte(context)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("AGENCE & TARIFICATION",
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexteAttenue(context),
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0646321E),
                    blurRadius: 10,
                    offset: Offset(0, 3))
              ],
            ),
            child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeService.instance.themeModeNotifier,
                      builder: (context, themeMode, _) {
                        return ListTile(
                          leading: Icon(
                            themeMode == ThemeMode.dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                            color: const Color(0xFF9E6738),
                          ),
                          title: Text("Thème de l'application",
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            themeMode == ThemeMode.dark
                                ? "Mode Sombre actif"
                                : themeMode == ThemeMode.light
                                    ? "Mode Clair actif"
                                    : "Adapté au système",
                            style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
                          ),
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<ThemeMode>(
                              value: themeMode,
                              items: const [
                                DropdownMenuItem(value: ThemeMode.light, child: Text("Clair ☀️")),
                                DropdownMenuItem(value: ThemeMode.dark, child: Text("Sombre 🌙")),
                                DropdownMenuItem(value: ThemeMode.system, child: Text("Système ⚙️")),
                              ],
                              onChanged: (val) {
                                if (val != null) ThemeService.instance.changerMode(val);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                    ListTile(
                      leading: const Icon(Icons.flight_takeoff_rounded,
                          color: Color(0xFF9E6738)),
                      title: Text("Tarifs Fret Aérien & Maritime",
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          "4 500 F/kg Istanbul • 3 800 F/kg Guangzhou",
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFFC7B8AA)),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Édition de la grille tarifaire au kilo")),
                        );
                      },
                    ),
                    const Divider(
                        height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                    ListTile(
                      leading: const Icon(Icons.store_mall_directory_rounded,
                          color: Color(0xFF9E6738)),
                      title: Text("Dépôts & Points Relais Bamako",
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          "Grand Marché Dabanani (Porte 14) & Halles de Bamako",
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFFC7B8AA)),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "Point Relais Dabanani (Porte 14) : Ouvert du Lundi au Samedi de 08h à 18h30."),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                    const Divider(
                        height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                    ListTile(
                      leading:
                          Icon(Icons.shield_outlined, color: Color(0xFF9E6738)),
                      title: Text("Agrément Douanes Mali",
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text("NIF 084192043M • Licence CEMAC/UEMOA",
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                      trailing: Icon(Icons.verified,
                          color: AppTheme.success, size: 18),
                    ),
                    const Divider(
                        height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded,
                          color: Color(0xFF9E6738)),
                      title: Text("Mot de passe du compte",
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          "Modifier le mot de passe de votre espace Agence Logistique",
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFFC7B8AA)),
                      onTap: () => afficherDialogueChangerMotDePasse(context),
                    ),
                  ],
                )),
          ),

          const SizedBox(height: 24),

          Text("ALERTES & COMMUNICATIONS",
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexteAttenue(context),
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0646321E),
                    blurRadius: 10,
                    offset: Offset(0, 3))
              ],
            ),
            child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: const Color(0xFF9E6738),
                      activeTrackColor:
                          const Color(0xFF9E6738).withValues(alpha: 0.4),
                      title: Text("SMS automatiques aux commerçants",
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          "Notification à chaque étape pointée (Douane, Dépôt, Retrait)",
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                      value: _smsCommercants,
                      onChanged: (val) => setState(() => _smsCommercants = val),
                    ),
                    const Divider(
                        height: 1, indent: 56, color: Color(0xFFF3ECE5)),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFF9E6738),
                      activeTrackColor:
                          const Color(0xFF9E6738).withValues(alpha: 0.4),
                      title: Text("Alertes Dédouanement Karavan",
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          "Notifications de transmission des manifestes",
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                      value: _alertesDouanes,
                      onChanged: (val) => setState(() => _alertesDouanes = val),
                    ),
                  ],
                )),
          ),

          const SizedBox(height: 24),

          // Section Développeur / Commutation de rôle
          Text("ESPACE DÉMONSTRATION & RÔLES",
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexteAttenue(context),
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0646321E),
                    blurRadius: 10,
                    offset: Offset(0, 3))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tester les autres espaces (Navigation & FAB) :",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppTheme.couleurTexte(context)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/commercant'),
                        icon: const Icon(Icons.store, size: 16),
                        label: const Text("Commerçant",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9E6738),
                          side: const BorderSide(color: Color(0xFF9E6738)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/grossiste'),
                        icon: const Icon(Icons.storefront_rounded, size: 16),
                        label: const Text("Grossiste",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
