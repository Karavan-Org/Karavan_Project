import 'package:flutter/foundation.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';

class PortefeuilleInfo {
  final double soldeBloque;
  final double soldeDisponible;
  final String devise;

  const PortefeuilleInfo({
    required this.soldeBloque,
    required this.soldeDisponible,
    required this.devise,
  });

  factory PortefeuilleInfo.fromJson(Map<String, dynamic> json) {
    double decimal(Object? v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    return PortefeuilleInfo(
      soldeBloque: decimal(json['soldeBloque']),
      soldeDisponible: decimal(json['soldeDisponible']),
      devise: json['devise']?.toString() ?? 'XOF',
    );
  }
}

class MouvementPortefeuille {
  final int id;
  final String type;
  final double montant;
  final DateTime? date;
  final String reference;

  const MouvementPortefeuille({
    required this.id,
    required this.type,
    required this.montant,
    this.date,
    required this.reference,
  });

  factory MouvementPortefeuille.fromJson(Map<String, dynamic> json) {
    int entier(Object? v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    double decimal(Object? v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    return MouvementPortefeuille(
      id: entier(json['id']),
      type: json['type']?.toString() ?? '',
      montant: decimal(json['montant']),
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      reference: json['reference']?.toString() ?? '',
    );
  }
}

class PortefeuilleApiService {
  PortefeuilleApiService._();
  static final PortefeuilleApiService instance = PortefeuilleApiService._();

  /// Récupère le solde du portefeuille en direct depuis le backend (RG-41)
  Future<PortefeuilleInfo?> voirPortefeuille() async {
    try {
      final rep = await ApiClient.instance.get(ApiConfig.portefeuille);
      if (rep is Map<String, dynamic>) {
        return PortefeuilleInfo.fromJson(rep);
      }
      return null;
    } catch (e) {
      debugPrint('PortefeuilleApiService.voirPortefeuille - Erreur : $e');
      return null;
    }
  }

  /// Récupère l'historique complet des mouvements financiers du portefeuille
  Future<List<MouvementPortefeuille>> mesMouvements({int taille = 50}) async {
    try {
      final rep = await ApiClient.instance.get(ApiConfig.portefeuilleMouvements, queryParams: {'taille': taille});
      if (rep is List) {
        return rep.map((item) => MouvementPortefeuille.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
      return [];
    } catch (e) {
      debugPrint('PortefeuilleApiService.mesMouvements - Erreur : $e');
      return [];
    }
  }

  /// Recharge dynamique du portefeuille (Orange Money, Moov, Wave)
  Future<PortefeuilleInfo?> recharger({
    required double montant,
    required String operateur,
    String? numeroTelephone,
  }) async {
    final rep = await ApiClient.instance.post(
      ApiConfig.portefeuilleRecharge,
      body: {
        'montant': montant,
        'operateur': operateur,
        'numeroTelephone': numeroTelephone,
      },
    );
    if (rep is Map<String, dynamic>) {
      return PortefeuilleInfo.fromJson(rep);
    }
    return null;
  }
}
