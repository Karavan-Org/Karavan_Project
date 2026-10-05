import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran des Notifications Commerçant (Frame Figma "Notifications")
class NotificationsCommercantScreen extends StatefulWidget {
  const NotificationsCommercantScreen({super.key});

  @override
  State<NotificationsCommercantScreen> createState() => _NotificationsCommercantScreenState();
}

class _NotificationsCommercantScreenState extends State<NotificationsCommercantScreen> {
  String _selectedFiltre = "Toutes";

  final List<Map<String, dynamic>> _notifications = [
    {
      "categorie": "Groupes",
      "titre": "Groupe validé",
      "message": "Sneakers Premium est validé",
      "date": "12 sept. 2026 - 10:34",
      "icon": Icons.check_circle_rounded,
      "color": AppTheme.success,
      "lu": false,
    },
    {
      "categorie": "Commandes",
      "titre": "Paiement confirmé",
      "message": "Votre paiement a été reçu",
      "date": "10 sept. 2026 - 09:48",
      "icon": Icons.verified_rounded,
      "color": AppTheme.success,
      "lu": false,
    },
    {
      "categorie": "Commandes",
      "titre": "Colis chez le transitaire",
      "message": "Votre marchandise est en transit",
      "date": "08 sept. 2026 - 14:32",
      "icon": Icons.local_shipping_rounded,
      "color": const Color(0xFFF57C00),
      "lu": false,
    },
    {
      "categorie": "Groupes",
      "titre": "Rappel de délai",
      "message": "Le groupe Sneakers Premium se termine bientôt",
      "date": "12 sept. 2026",
      "icon": Icons.hourglass_top_rounded,
      "color": const Color(0xFFF57C00),
      "lu": true,
    },
    {
      "categorie": "Commandes",
      "titre": "Remboursement effectué",
      "message": "212 500 FCFA versé",
      "date": "05 sept. 2026",
      "icon": Icons.account_balance_wallet_rounded,
      "color": AppTheme.success,
      "lu": true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final list = _selectedFiltre == "Toutes"
        ? _notifications
        : _notifications.where((n) => n["categorie"] == _selectedFiltre).toList();

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
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n["lu"] = true;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Toutes les notifications marquées comme lues"),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text(
              "Tout marquer lu",
              style: TextStyle(fontSize: 11.5, color: Color(0xFF9E6738), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filtres pilules
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip("Toutes", "Toutes (8)"),
                const SizedBox(width: 8),
                _buildFilterChip("Groupes", "Groupes (3)"),
                const SizedBox(width: 8),
                _buildFilterChip("Commandes", "Commandes (5)"),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Liste des notifications
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = list[index];
                final Color iconColor = notif["color"] as Color;
                final bool estLu = notif["lu"] as bool;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: estLu ? Colors.transparent : const Color(0xFF9E6738).withValues(alpha: 0.18),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icône colorée
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: iconColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notif["icon"] as IconData,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Contenu
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif["titre"] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Color(0xFF2C241E),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notif["message"] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5A493B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif["date"] as String,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF8C7E74),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!estLu)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFiltre == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFiltre = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9E6738) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF9E6738) : const Color(0xFFE5DDD5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF5A493B),
          ),
        ),
      ),
    );
  }
}
