import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../services/api/api_config.dart';
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
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerNotifications();
  }

  Future<void> _chargerNotifications() async {
    setState(() => _chargement = true);
    try {
      final res = await ApiClient.instance.get(ApiConfig.notifications);
      if (res is List) {
        if (!mounted) return;
        setState(() {
          _notifications.clear();
          for (final item in res) {
            final contenu = item['contenu']?.toString() ?? '';
            final statut = item['statut']?.toString() ?? '';
            final id = item['id'];
            final dateStr = item['date']?.toString() ?? '';

            String cat = "Convois";
            IconData icon = Icons.local_shipping_rounded;
            Color col = const Color(0xFF1E88E5);
            if (contenu.toLowerCase().contains("retrait") ||
                contenu.toLowerCase().contains("colis") ||
                contenu.toLowerCase().contains("code") ||
                contenu.toLowerCase().contains("scanner")) {
              cat = "Retraits";
              icon = Icons.qr_code_scanner_rounded;
              col = const Color(0xFF43A047);
            }

            String dateAffichee = "Récemment";
            if (dateStr.isNotEmpty) {
              try {
                final d = DateTime.parse(dateStr).toLocal();
                dateAffichee = "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}";
              } catch (_) {}
            }

            _notifications.add({
              "id": id,
              "titre": cat == "Retraits" ? "Retrait client" : "Transit & Convoi",
              "message": contenu,
              "date": dateAffichee,
              "categorie": cat,
              "lu": statut == "LUE",
              "icon": icon,
              "color": col,
            });
          }
        });
      }
    } catch (_) {
      // Tolérer le mode hors-ligne
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _marquerToutesLues() async {
    for (var n in _notifications) {
      final id = n["id"];
      if (id != null && n["lu"] != true) {
        ApiClient.instance.post("${ApiConfig.notifications}/$id/lue").catchError((_) => null);
      }
      n["lu"] = true;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Toutes les notifications marquées comme lues"),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _selectedFiltre == "Toutes"
        ? _notifications
        : _notifications.where((n) => n["categorie"] == _selectedFiltre).toList();

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Notifications Courtier",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _marquerToutesLues,
              child: const Text(
                "Tout marquer lu",
                style: TextStyle(fontSize: 11.5, color: Color(0xFF9E6738), fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _chargerNotifications,
        color: const Color(0xFF9E6738),
        child: Column(
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
              child: _chargement
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF9E6738)),
                    )
                  : list.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 80, left: 32, right: 32),
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
                                  Text(
                                    "Aucune notification",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppTheme.couleurTexte(context),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Les mises à jour logistiques et retraits validés s'afficheront ici.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                                color: AppTheme.couleurCarte(context),
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
                                      color: AppTheme.couleurCarte(context),
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            color: AppTheme.couleurTexte(context),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          notif["message"] as String,
                                          style: TextStyle(fontSize: 12, color: AppTheme.couleurTexte(context)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif["date"] as String,
                                          style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
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
          color: isSelected ? const Color(0xFF9E6738) : AppTheme.couleurCarte(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF9E6738) : AppTheme.couleurBordure(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.couleurTexte(context),
          ),
        ),
      ),
    );
  }
}
