import 'dart:typed_data';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';

/// Types de pièces acceptés par le backend (ml.dogo.identite.domain.TypeDocument)
enum TypeDocumentKyc { pieceIdentite, registreCommerce, nif, releveBancaire, autre }

extension TypeDocumentKycCode on TypeDocumentKyc {
  String get code => switch (this) {
        TypeDocumentKyc.pieceIdentite => 'PIECE_IDENTITE',
        TypeDocumentKyc.registreCommerce => 'REGISTRE_COMMERCE',
        TypeDocumentKyc.nif => 'NIF',
        TypeDocumentKyc.releveBancaire => 'RELEVE_BANCAIRE',
        TypeDocumentKyc.autre => 'AUTRE',
      };
}

/// Une pièce prête à l'envoi (photo prise, image ou PDF importé)
class PieceKyc {
  final TypeDocumentKyc type;
  final String nomFichier;
  final Uint8List octets;

  const PieceKyc({required this.type, required this.nomFichier, required this.octets});
}

/// Dossier KYC tel que renvoyé par GET /api/kyc/moi
class DossierKyc {
  final int id;
  final String statut; // EN_ATTENTE, APPROUVE, REJETE
  final String? motifRejet;
  final DateTime? dateSoumission;
  final List<String> typesDocuments;

  const DossierKyc({
    required this.id,
    required this.statut,
    this.motifRejet,
    this.dateSoumission,
    this.typesDocuments = const [],
  });

  factory DossierKyc.fromJson(Map<String, dynamic> json) => DossierKyc(
        id: (json['id'] as num).toInt(),
        statut: json['statut'] as String? ?? 'EN_ATTENTE',
        motifRejet: json['motifRejet'] as String?,
        dateSoumission: DateTime.tryParse(json['dateSoumission']?.toString() ?? ''),
        typesDocuments: (json['documents'] as List<dynamic>? ?? [])
            .map((d) => (d as Map)['type'].toString())
            .toList(),
      );
}

/// Service du dossier de vérification (RG-03 à RG-05)
class KycApiService {
  KycApiService._();
  static final KycApiService instance = KycApiService._();

  /// Pièces exigées pour un Grossiste (TypeDocument.obligatoiresPour côté backend)
  static const Set<TypeDocumentKyc> obligatoiresGrossiste = {
    TypeDocumentKyc.pieceIdentite,
    TypeDocumentKyc.registreCommerce,
    TypeDocumentKyc.nif,
  };

  static const int tailleMaxOctets = 5 * 1024 * 1024;

  final ApiClient _api = ApiClient.instance;

  /// Dépose le dossier : le backend associe types[i] à fichiers[i]
  Future<DossierKyc> soumettre(List<PieceKyc> pieces) async {
    final response = await _api.postMultipartFichiers(
      ApiConfig.kyc,
      fieldName: 'fichiers',
      fichiers: pieces.map((p) => (bytes: p.octets.toList(), filename: p.nomFichier)).toList(),
      // Spring convertit une valeur séparée par des virgules en List<TypeDocument>
      fields: {'types': pieces.map((p) => p.type.code).join(',')},
    );
    return DossierKyc.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Dernier dossier déposé, ou null si aucun dossier n'a encore été envoyé
  Future<DossierKyc?> monDossier() async {
    try {
      final response = await _api.get(ApiConfig.monDossierKyc);
      return DossierKyc.fromJson(Map<String, dynamic>.from(response as Map));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Signature binaire acceptée par le backend : PDF, JPEG ou PNG
  static bool formatAccepte(Uint8List c) {
    if (c.length < 4) return false;
    final pdf = c[0] == 0x25 && c[1] == 0x50 && c[2] == 0x44 && c[3] == 0x46;
    final jpeg = c[0] == 0xFF && c[1] == 0xD8 && c[2] == 0xFF;
    final png = c[0] == 0x89 && c[1] == 0x50 && c[2] == 0x4E && c[3] == 0x47;
    return pdf || jpeg || png;
  }
}
