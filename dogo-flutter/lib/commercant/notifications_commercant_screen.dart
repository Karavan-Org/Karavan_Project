import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../services/api/api_config.dart';
import '../services/plus_code.dart';
import '../theme/app_theme.dart';
import '../widgets/itineraire_depot.dart';

import 'mes_commandes_screen.dart';
import 'portefeuille_commercant_screen.dart';

/// Écran des Notifications Commerçant (Frame Figma "Notifications")
class NotificationsCommercantScreen extends StatefulWidget {
  const NotificationsCommercantScreen({super.key});

  @override
  State<NotificationsCommercantScreen> createState() => _NotificationsCommercantScreenState();
}

class _NotificationsCommercantScreenState extends State<NotificationsCommercantScreen> {
  String _selectedFiltre = "Toutes";
  final List<Map<String, dynamic>> _notifications = [];
  bool _chargement = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _chargerNotifications();
    // Actualisation Live automatique toutes les 4 secondes
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _chargerNotifications(silencieux: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _chargerNotifications({bool silencieux = false}) async {
    if (!silencieux) {
      setState(() => _chargement = true);
    }
    try {
      final res = await ApiClient.instance.get(ApiConfig.notifications);
      if (res is List) {
        if (!mounted) return;
        final nouvelles = <Map<String, dynamic>>[];
        for (final item in res) {
          final contenu = item['contenu']?.toString() ?? '';
          final statut = item['statut']?.toString() ?? '';
          final id = item['id'];
          final dateStr = item['date']?.toString() ?? '';

          final cLower = contenu.toLowerCase();
          String cat = "Groupes";
          IconData icon = Icons.groups_rounded;
          Color col = const Color(0xFF2E7D32);
          String titre = "Groupe d'achat";

          if (cLower.contains("rembours") ||
              cLower.contains("portefeuille") ||
              cLower.contains("séquestre")) {
            cat = "Remboursements";
            icon = Icons.account_balance_wallet_rounded;
            col = const Color(0xFF1B5E20);
            titre = "Remboursement & Portefeuille";
          } else if (cLower.contains("colis") ||
              cLower.contains("commande") ||
              cLower.contains("retrait") ||
              cLower.contains("livraison") ||
              cLower.contains("dépôt") ||
              cLower.contains("depot")) {
            cat = "Commandes";
            icon = Icons.local_shipping_rounded;
            col = const Color(0xFFE65100);
            titre = (cLower.contains("dépôt") || cLower.contains("depot"))
                ? "Colis disponible au dépôt"
                : "Suivi de commande";
          }

          String dateAffichee = "Récemment";
          if (dateStr.isNotEmpty) {
            try {
              final d = DateTime.parse(dateStr).toLocal();
              dateAffichee = "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}";
            } catch (_) {}
          }

          final lienMaps = _extraireLienGoogleMaps(contenu);
          final depot = _extraireDepot(contenu);
          final bool aCodeRetrait = cLower.contains("code pin") ||
              cLower.contains("qr code") ||
              cLower.contains("code de retrait") ||
              cLower.contains("pin :");

          nouvelles.add({
            "id": id,
            "titre": titre,
            "message": contenu
                .replaceAll(RegExp(r'\s*Localisation Google Maps\s*:\s*\S+', caseSensitive: false), '')
                .trim(),
            "date": dateAffichee,
            "categorie": cat,
            "lu": statut == "LUE",
            "icon": icon,
            "color": col,
            "lienMaps": lienMaps,
            "depotNom": depot.$1,
            "depotAdresse": depot.$2,
            "aCodeRetrait": aCodeRetrait,
          });
        }
        // Déduplication intelligente : évite d'afficher des notifications doublons
        final sansDoublons = <Map<String, dynamic>>[];
        final signaturesVues = <String>{};

        for (final notif in nouvelles) {
          final msg = notif['message'] as String;
          final date = notif['date'] as String;
          final bool aCode = notif['aCodeRetrait'] == true;
          final depotNom = notif['depotNom'] as String? ?? '';

          final cleExacte = "${msg}_$date";
          if (signaturesVues.contains(cleExacte)) {
            continue;
          }

          if (depotNom.isNotEmpty) {
            final cleGroupe = "depot_${depotNom}_$date";
            if (!aCode && signaturesVues.contains("${cleGroupe}_avec_code")) {
              continue;
            }
            if (aCode) {
              signaturesVues.add("${cleGroupe}_avec_code");
              sansDoublons.removeWhere((item) =>
                  item['depotNom'] == depotNom &&
                  item['date'] == date &&
                  item['aCodeRetrait'] != true);
            }
          }

          signaturesVues.add(cleExacte);
          sansDoublons.add(notif);
        }

        setState(() {
          _notifications.clear();
          _notifications.addAll(sansDoublons);
        });
      }
    } catch (_) {
      // Tolérer le mode hors-ligne
    } finally {
      if (mounted && !silencieux) setState(() => _chargement = false);
    }
  }

  String? _extraireLienGoogleMaps(String message) {
    // Extrait l'URL en préservant les virgules internes (ex: ?q=12.6392,-7.9982)
    // tout en retirant les éventuelles ponctuations finales de fin de phrase.
    final reg = RegExp(r'https?://[^\s)\]">]+', caseSensitive: false);
    final matches = reg.allMatches(message);
    for (final m in matches) {
      var url = m.group(0)!;
      url = url.replaceAll(RegExp(r'[.,;!]+$'), '');
      if (url.contains('maps') || url.contains('goo.gl') || url.contains('google.com/maps')) {
        return url;
      }
    }
    return null;
  }

  /// Nom et adresse du dépôt tels qu'écrits par le backend : « … au dépôt <nom> (<adresse>) ! ».
  (String, String?) _extraireDepot(String message) {
    final m = RegExp(r'dépôt\s+([^(.!]+?)\s*(?:\(([^)]+)\))?\s*[.!]', caseSensitive: false).firstMatch(message);
    final nom = m?.group(1)?.trim();
    return ((nom == null || nom.isEmpty) ? "Dépôt DoGo" : nom, m?.group(2)?.trim());
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
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C241E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                "Notifications",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "En direct",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2C241E)),
            tooltip: "Actualiser",
            onPressed: () => _chargerNotifications(silencieux: false),
          ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Color(0xFF9E6738)),
              tooltip: "Tout marquer lu",
              onPressed: _marquerToutesLues,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _chargerNotifications,
        color: const Color(0xFF9E6738),
        child: Column(
          children: [
            // Filtres pilules avec défilement horizontal
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip("Toutes", "Toutes (${_notifications.length})"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Remboursements", "Remboursements (${_notifications.where((n) => n["categorie"] == "Remboursements").length})"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Commandes", "Commandes (${_notifications.where((n) => n["categorie"] == "Commandes").length})"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Groupes", "Groupes (${_notifications.where((n) => n["categorie"] == "Groupes").length})"),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Liste des notifications
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
                                    "Vous recevrez des alertes en temps réel sur vos remboursements, commandes et groupes.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
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
                            final bool estRemboursement = notif["categorie"] == "Remboursements";
                            final String? lienMaps = notif["lienMaps"] as String?;
                            final bool aCodeRetrait = (notif["aCodeRetrait"] as bool?) ?? false;

                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                if (!estLu && notif["id"] != null) {
                                  ApiClient.instance.post("${ApiConfig.notifications}/${notif["id"]}/lue").catchError((_) => null);
                                  setState(() => notif["lu"] = true);
                                }
                              },
                              child: Container(
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
                                      width: 40,
                                      height: 40,
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
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                notif["date"] as String,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF8C7E74),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (estRemboursement) ...[
                                            const SizedBox(height: 10),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () {
                                                if (!estLu && notif["id"] != null) {
                                                  ApiClient.instance.post("${ApiConfig.notifications}/${notif["id"]}/lue").catchError((_) => null);
                                                  setState(() => notif["lu"] = true);
                                                }
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => const PortefeuilleCommercantScreen(),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(0xFF1B5E20).withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.account_balance_wallet_rounded,
                                                      size: 15,
                                                      color: Color(0xFF1B5E20),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        "Consulter mon portefeuille",
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF1B5E20),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Icon(
                                                      Icons.chevron_right_rounded,
                                                      size: 15,
                                                      color: Color(0xFF1B5E20),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (lienMaps != null || PlusCode.depuisTexte(notif["depotAdresse"] as String?) != null) ...[
                                            const SizedBox(height: 10),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () {
                                                if (!estLu && notif["id"] != null) {
                                                  ApiClient.instance.post("${ApiConfig.notifications}/${notif["id"]}/lue").catchError((_) => null);
                                                  setState(() => notif["lu"] = true);
                                                }
                                                afficherItineraireDepot(
                                                  context,
                                                  nomDepot: notif["depotNom"] as String,
                                                  adresse: notif["depotAdresse"] as String?,
                                                  lienGoogleMaps: lienMaps,
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.directions_rounded,
                                                      size: 15,
                                                      color: Color(0xFF1A73E8),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        "Voir l'itinéraire vers le dépôt",
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF1A73E8),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Icon(
                                                      Icons.chevron_right_rounded,
                                                      size: 15,
                                                      color: Color(0xFF1A73E8),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (aCodeRetrait) ...[
                                            const SizedBox(height: 8),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () {
                                                if (!estLu && notif["id"] != null) {
                                                  ApiClient.instance.post("${ApiConfig.notifications}/${notif["id"]}/lue").catchError((_) => null);
                                                  setState(() => notif["lu"] = true);
                                                }
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => const MesCommandesScreen(),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE65100).withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(0xFFE65100).withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.qr_code_rounded,
                                                      size: 15,
                                                      color: Color(0xFFE65100),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        "📦 Présenter mon code de retrait",
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFFE65100),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Icon(
                                                      Icons.chevron_right_rounded,
                                                      size: 15,
                                                      color: Color(0xFFE65100),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
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
