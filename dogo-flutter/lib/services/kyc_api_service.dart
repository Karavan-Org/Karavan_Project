import 'dart:typed_data';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/api_exception.dart';
import 'auth_service.dart';

/// Types de pièces acceptés par le backend (ml.dogo.identite.domain.TypeDocument)
enum TypeDocumentKyc { pieceIdentite, registreCommerce, nif, licenceTransit, releveBancaire, autre }

extension TypeDocumentKycCode on TypeDocumentKyc {
  String get code => switch (this) {
        TypeDocumentKyc.pieceIdentite => 'PIECE_IDENTITE',
        TypeDocumentKyc.registreCommerce => 'REGISTRE_COMMERCE',
        TypeDocumentKyc.nif => 'NIF',
        TypeDocumentKyc.licenceTransit => 'LICENCE_TRANSIT',
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

/// Modèle alternatif / adaptateur pour l'UI de soumission de documents
class PieceDocumentKyc {
  final dynamic type;
  final String nomFichier;
  final Uint8List octets;

  const PieceDocumentKyc({
    required this.type,
    required this.nomFichier,
    required this.octets,
  });

  TypeDocumentKyc get typeKyc {
    if (type is TypeDocumentKyc) return type as TypeDocumentKyc;
    final str = type.toString().toUpperCase();
    if (str.contains('IDENTITE')) return TypeDocumentKyc.pieceIdentite;
    if (str.contains('COMMERCE')) return TypeDocumentKyc.registreCommerce;
    if (str.contains('NIF')) return TypeDocumentKyc.nif;
    if (str.contains('LICENCE')) return TypeDocumentKyc.licenceTransit;
    if (str.contains('BANCAIRE')) return TypeDocumentKyc.releveBancaire;
    return TypeDocumentKyc.autre;
  }

  PieceKyc toPieceKyc() => PieceKyc(
        type: typeKyc,
        nomFichier: nomFichier,
        octets: octets,
      );
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

  /// Pièces exigées pour un Courtier (TypeDocument.obligatoiresPour côté backend)
  static const Set<TypeDocumentKyc> obligatoiresCourtier = {
    TypeDocumentKyc.pieceIdentite,
    TypeDocumentKyc.licenceTransit,
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

  /// Dépose le dossier via liste de PieceDocumentKyc (utilisé par le formulaire Grossiste)
  Future<DossierKyc> soumettreDossier({required List<PieceDocumentKyc> pieces}) async {
    return soumettre(pieces.map((p) => p.toPieceKyc()).toList());
  }

  /// Vérifie le statut du compte et du dossier KYC
  Future<Map<String, dynamic>?> verifierStatutCompte() async {
    try {
      final profil = await AuthService.instance.rechargerProfil();
      final dossier = await monDossier();
      return {
        'statut': profil?.statut ?? dossier?.statut ?? 'EN_ATTENTE',
        'dossierStatut': dossier?.statut,
        'motifRejet': dossier?.motifRejet,
      };
    } catch (_) {
      return null;
    }
  }

  /// Extensions proposées par le sélecteur de fichiers (images, PDF et documents électroniques)
  static const extensionsAcceptees = [
    'pdf', 'jpg', 'jpeg', 'png', //
    'doc', 'docx', 'odt', 'rtf', 'txt', //
    'xls', 'xlsx', 'ods', 'csv',
  ];

  /// Même contrôle que le backend (FormatPiece) : le contenu doit correspondre au format annoncé.
  /// PDF, JPEG et PNG sont reconnus à leur signature ; les autres d'après l'extension + signature.
  static bool formatAccepte(Uint8List c, String nom) {
    if (c.length < 4) return false;
    final pdf = c[0] == 0x25 && c[1] == 0x50 && c[2] == 0x44 && c[3] == 0x46;
    final jpeg = c[0] == 0xFF && c[1] == 0xD8 && c[2] == 0xFF;
    final png = c[0] == 0x89 && c[1] == 0x50 && c[2] == 0x4E && c[3] == 0x47;
    if (pdf || jpeg || png) return true;

    final point = nom.lastIndexOf('.');
    final ext = point < 0 ? '' : nom.substring(point + 1).toLowerCase().trim();
    final zip = c[0] == 0x50 && c[1] == 0x4B && c[2] == 0x03 && c[3] == 0x04;
    const ole2 = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
    final estOle2 = c.length >= 8 && List.generate(8, (i) => c[i] == ole2[i]).every((ok) => ok);
    return switch (ext) {
      'docx' || 'xlsx' || 'odt' || 'ods' => zip,
      'doc' || 'xls' => estOle2,
      'rtf' => c.length >= 5 && String.fromCharCodes(c.sublist(0, 5)) == r'{\rtf',
      'txt' || 'csv' => c.every((b) => (b >= 0x20 && b != 0x7F) || b == 0x09 || b == 0x0A || b == 0x0D || b == 0x0C),
      _ => false,
    };
  }
}
