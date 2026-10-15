import 'api/api_client.dart';

class NotificationItem {
  final int id;
  final String contenu;
  final String canal;
  final String statut;
  final DateTime? date;

  const NotificationItem({
    required this.id,
    required this.contenu,
    required this.canal,
    required this.statut,
    this.date,
  });

  bool get estLue => statut == 'LUE';

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as num).toInt(),
      contenu: json['contenu'] as String? ?? '',
      canal: json['canal'] as String? ?? 'SMS',
      statut: json['statut'] as String? ?? 'ENVOYEE',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
    );
  }
}

class NotificationApiService {
  NotificationApiService._();
  static final NotificationApiService instance = NotificationApiService._();

  Future<List<NotificationItem>> mesNotifications({int taille = 50}) async {
    final rep = await ApiClient.instance.get('/api/moi/notifications', queryParams: {'taille': taille});
    if (rep is! List) return [];
    return rep.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> marquerLue(int id) async {
    await ApiClient.instance.post('/api/moi/notifications/$id/lue');
  }

  Future<int> nombreNonLues() async {
    try {
      final notifs = await mesNotifications(taille: 50);
      return notifs.where((n) => !n.estLue).length;
    } catch (_) {
      return 0;
    }
  }
}

