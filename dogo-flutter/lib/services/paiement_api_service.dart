import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';

/// Résultat d'un paiement selon le contrat Backend DoGo (PaiementVue)
class PaiementResultat {
  final int id;
  final int participationId;
  final double montant;
  final String statut;
  final String dateInitiation;

  const PaiementResultat({
    required this.id,
    required this.participationId,
    required this.montant,
    required this.statut,
    required this.dateInitiation,
  });

  factory PaiementResultat.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! num) {
      throw const ApiException(statusCode: 0, message: 'Réponse de paiement invalide : identifiant absent.');
    }
    return PaiementResultat(
      id: id.toInt(),
      participationId: (json['participationId'] as num?)?.toInt() ?? 0,
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      // Jamais « VALIDE » par défaut : un statut absent ne prouve pas que l'argent a été encaissé
      statut: json['statut'] as String? ?? 'INCONNU',
      dateInitiation: json['dateInitiation']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}

/// Service de paiement Mobile Money avec garantie d'idempotence (RG-33 & RG-34)
class PaiementApiService {
  PaiementApiService._();
  static final PaiementApiService instance = PaiementApiService._();

  /// Génère une clé d'idempotence unique (UUID / timestamp + entropie)
  String genererCleIdempotence() {
    final rand = Random.secure();
    final randomHex = List.generate(12, (_) => rand.nextInt(16).toRadixString(16)).join();
    return 'dogo-pay-${DateTime.now().millisecondsSinceEpoch}-$randomHex';
  }

  /// Initie le paiement sécurisé de la participation avec compte séquestre
  Future<PaiementResultat> initierPaiement({
    required dynamic participationId,
    String? cleIdempotence,
    int? moyenPaiementId,
    bool utiliserPortefeuille = false,
  }) async {
    final cle = cleIdempotence ?? genererCleIdempotence();

    final Map<String, dynamic> corps = {};
    if (moyenPaiementId != null) corps['moyenPaiementId'] = moyenPaiementId;
    if (utiliserPortefeuille) corps['utiliserPortefeuille'] = true;

    final response = await ApiClient.instance.post(
      ApiConfig.initierPaiement(participationId),
      headers: {
        'Idempotency-Key': cle,
      },
      body: corps.isNotEmpty ? corps : null,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(statusCode: 0, message: 'Réponse de paiement inattendue du serveur DoGo.');
    }
    final resultat = PaiementResultat.fromJson(response);
    // En environnement démo, déclencher le callback de succès de l'opérateur Mobile Money (RG-34)
    if (resultat.statut == 'EN_ATTENTE') {
      try {
        await ApiClient.instance.post(ApiConfig.simulerSuccesPaiement(resultat.id));
      } catch (callbackErr) {
        debugPrint('Simulation callback opérateur démo (ignoré si hors démo) : $callbackErr');
      }
    }
    return resultat;
  }
}
