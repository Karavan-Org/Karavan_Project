import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran des Notifications du Courtier (Alertes Convois, Douanes et Retraits clients)
class NotificationsCourtierScreen extends StatefulWidget {
  const NotificationsCourtierScreen({super.key});

  @override
  State<NotificationsCourtierScreen> createState() => _NotificationsCourtierScreenState();
}

class _NotificationsCourtierScreenState extends State<NotificationsCourtierScreen> {
  String _selectedFiltre = "Toutes";

  final List<Map<String, dynamic>> _notifications = [];

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
          "Notifications Courtier",
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip("Toutes", "Toutes (${_notifications.length})"),
                const SizedBox(width: 8),
                _buildFilterChip("Convois", "Convois (${_notifications.where((n) => n["categorie"] == "Convois").length})"),
                const SizedBox(width: 8),
                _buildFilterChip("Retraits", "Retraits (${_notifications.where((n) => n["categorie"] == "Retraits").length})"),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 40,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Aucune notification",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF2C241E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Les mises à jour logistiques et retraits validés s'afficheront ici.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
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
                              style: const TextStyle(fontSize: 12, color: Color(0xFF5A493B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif["date"] as String,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
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
