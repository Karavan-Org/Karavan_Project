import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_api_service.dart';
import '../services/api/api_exception.dart';

/// Écran des Notifications du Grossiste avec données réelles du backend
class NotificationsGrossisteScreen extends StatefulWidget {
  const NotificationsGrossisteScreen({super.key});

  @override
  State<NotificationsGrossisteScreen> createState() => _NotificationsGrossisteScreenState();
}

class _NotificationsGrossisteScreenState extends State<NotificationsGrossisteScreen> {
  String _selectedFiltre = "Toutes";
  bool _chargement = true;
  String? _erreur;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final notifs = await NotificationApiService.instance.mesNotifications(taille: 50);
      if (!mounted) return;
      setState(() {
        _notifications = notifs;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : "Impossible de charger les notifications.";
        _chargement = false;
      });
    }
  }

  Future<void> _marquerLue(NotificationItem notif) async {
    if (notif.estLue) return;
    try {
      await NotificationApiService.instance.marquerLue(notif.id);
      if (!mounted) return;
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notif.id);
        if (index != -1) {
          _notifications[index] = NotificationItem(
            id: notif.id,
            contenu: notif.contenu,
            canal: notif.canal,
            statut: 'LUE',
            date: notif.date,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _toutMarquerLu() async {
    final nonLues = _notifications.where((n) => !n.estLue).toList();
    if (nonLues.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Future.wait(nonLues.map((n) => NotificationApiService.instance.marquerLue(n.id)));
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) => NotificationItem(
          id: n.id,
          contenu: n.contenu,
          canal: n.canal,
          statut: 'LUE',
          date: n.date,
        )).toList();
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Toutes les notifications sont marquées comme lues"),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : "Erreur lors du marquage."),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }

  String _determinerCategorie(String contenu) {
    final lower = contenu.toLowerCase();
    if (lower.contains('stock') || lower.contains('disponibilité')) {
      return 'Stock';
    }
    if (lower.contains('groupe') || lower.contains('campagne') || lower.contains('objectif')) {
      return 'Groupes';
    }
    if (lower.contains('commande') || lower.contains('achat')) {
      return 'Commandes';
    }
    if (lower.contains('kyc') || lower.contains('document') || lower.contains('validation')) {
      return 'Compte';
    }
    return 'Général';
  }

  IconData _iconeCategorie(String cat) {
    return switch (cat) {
      'Stock' => Icons.inventory_2_outlined,
      'Groupes' => Icons.groups_outlined,
      'Commandes' => Icons.shopping_bag_outlined,
      'Compte' => Icons.verified_user_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }

  Color _couleurCategorie(String cat) {
    return switch (cat) {
      'Stock' => const Color(0xFFB45309),
      'Groupes' => AppTheme.primary,
      'Commandes' => const Color(0xFF1976D2),
      'Compte' => const Color(0xFF2E7D32),
      _ => const Color(0xFF8C7E74),
    };
  }

  String _formaterDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours} h";
    if (diff.inDays < 7) return "Il y a ${diff.inDays} j";
    return "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final list = switch (_selectedFiltre) {
      "Non lues" => _notifications.where((n) => !n.estLue).toList(),
      "Stock" => _notifications.where((n) => _determinerCategorie(n.contenu) == "Stock").toList(),
      "Groupes" => _notifications.where((n) => _determinerCategorie(n.contenu) == "Groupes").toList(),
      "Compte" => _notifications.where((n) => _determinerCategorie(n.contenu) == "Compte").toList(),
      _ => _notifications,
    };

    final nombreNonLues = _notifications.where((n) => !n.estLue).length;

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
          "Notifications Grossiste",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
        actions: [
          if (nombreNonLues > 0)
            TextButton(
              onPressed: _toutMarquerLu,
              child: const Text(
                "Tout marquer lu",
                style: TextStyle(fontSize: 12, color: Color(0xFF9E6738), fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        color: AppTheme.primary,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip("Toutes", "Toutes (${_notifications.length})"),
                  const SizedBox(width: 8),
                  if (nombreNonLues > 0) ...[
                    _buildFilterChip("Non lues", "Non lues ($nombreNonLues)"),
                    const SizedBox(width: 8),
                  ],
                  _buildFilterChip("Stock", "Stock (${_notifications.where((n) => _determinerCategorie(n.contenu) == "Stock").length})"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Groupes", "Groupes (${_notifications.where((n) => _determinerCategorie(n.contenu) == "Groupes").length})"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Compte", "Compte (${_notifications.where((n) => _determinerCategorie(n.contenu) == "Compte").length})"),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator())
                  : _erreur != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(40),
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Color(0xFFC0392B)),
                            const SizedBox(height: 12),
                            Text(_erreur!, textAlign: TextAlign.center),
                          ],
                        )
                      : list.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(40),
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Aucune notification",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2C241E)),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Les alertes de validation de stock et l'état de vos lots s'afficheront ici.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
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
                                final categorie = _determinerCategorie(notif.contenu);
                                final iconColor = _couleurCategorie(categorie);
                                final iconData = _iconeCategorie(categorie);
                                final estLu = notif.estLue;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _marquerLue(notif),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: estLu ? Colors.transparent : const Color(0xFF9E6738).withValues(alpha: 0.25),
                                          width: estLu ? 1 : 1.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: iconColor.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(iconData, color: iconColor, size: 20),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        categorie,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 12.5,
                                                          color: iconColor,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      _formaterDate(notif.date),
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF8C7E74)),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  notif.contenu,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: estLu ? FontWeight.w500 : FontWeight.w700,
                                                    color: const Color(0xFF2C241E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!estLu)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(left: 8, top: 4),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFE53935),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
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

