import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/kyc_api_service.dart';
import '../theme/app_theme.dart';
import 'camera_helper.dart';
import 'grossiste_en_attente_screen.dart';

class ElementDocumentAEnvoyer {
  final String titre;
  final String sousTitre;
  final String typeKyc;
  final bool obligatoire;
  final IconData icone;

  Uint8List? octets;
  String? nomFichier;
  int? tailleOctets;

  ElementDocumentAEnvoyer({
    required this.titre,
    required this.sousTitre,
    required this.typeKyc,
    required this.obligatoire,
    required this.icone,
    this.octets,
    this.nomFichier,
    this.tailleOctets,
  });

  bool get estRenseigne => octets != null && octets!.isNotEmpty;
}

/// Écran "Soumettre mes documents" conforme au Figma Frame 3
/// Permet au Grossiste de prendre en photo ou d'importer ses pièces administratives pour examen KYC.
class SoumettreDocumentsGrossisteScreen extends StatefulWidget {
  final String nomEntreprise;
  final String telephone;

  const SoumettreDocumentsGrossisteScreen({
    super.key,
    this.nomEntreprise = "Grand Dépôt Mandé",
    this.telephone = "",
  });

  @override
  State<SoumettreDocumentsGrossisteScreen> createState() => _SoumettreDocumentsGrossisteScreenState();
}

class _SoumettreDocumentsGrossisteScreenState extends State<SoumettreDocumentsGrossisteScreen> {
  final ImagePicker _picker = ImagePicker();
  static const int _tailleMaxOctets = 5 * 1024 * 1024; // 5 Mo

  bool _isSubmitting = false;

  late final List<ElementDocumentAEnvoyer> _documents;

  @override
  void initState() {
    super.initState();
    _documents = [
      ElementDocumentAEnvoyer(
        titre: "Pièce d'identité / Passeport",
        sousTitre: "PDF, JPG, PNG (max 5 Mo)",
        typeKyc: "PIECE_IDENTITE",
        obligatoire: true,
        icone: Icons.badge_outlined,
      ),
      ElementDocumentAEnvoyer(
        titre: "Justificatif d'activité (extrait, registre)",
        sousTitre: "PDF, JPG, PNG (max 5 Mo)",
        typeKyc: "REGISTRE_COMMERCE",
        obligatoire: true,
        icone: Icons.description_outlined,
      ),
      ElementDocumentAEnvoyer(
        titre: "Identifiant NIF",
        sousTitre: "PDF, JPG, PNG (max 5 Mo)",
        typeKyc: "NIF",
        obligatoire: true,
        icone: Icons.account_balance_outlined,
      ),
      ElementDocumentAEnvoyer(
        titre: "Autres documents (optionnel)",
        sousTitre: "PDF, JPG, PNG (max 5 Mo)",
        typeKyc: "AUTRE",
        obligatoire: false,
        icone: Icons.folder_open_outlined,
      ),
    ];
  }

  void _ouvrirSelectionDocument(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Ajouter : ${_documents[index].titre}",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              "Prenez une photo claire ou sélectionnez un fichier (PDF, JPG, PNG)",
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFA67954).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFA67954), size: 24),
              ),
              title: const Text("Prendre une photo", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text("Photographier votre document original", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _prendrePhotoDocument(index);
              },
            ),
            const Divider(height: 14),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_outlined, color: Color(0xFF1E1E24), size: 24),
              ),
              title: const Text("Choisir depuis la galerie ou fichiers", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text("Importer un scan PDF ou photo enregistrée", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _importerDepuisGalerieOuFichier(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prendrePhotoDocument(int index) async {
    try {
      if (kIsWeb) {
        final bytes = await ouvrirCameraWeb(context);
        if (bytes != null) {
          if (bytes.lengthInBytes > _tailleMaxOctets) {
            _afficherAlerteTaille(bytes.lengthInBytes);
            return;
          }
          setState(() {
            _documents[index].octets = bytes;
            _documents[index].nomFichier = "doc_${_documents[index].typeKyc.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg";
            _documents[index].tailleOctets = bytes.lengthInBytes;
          });
          _afficherSucces("Photo du document enregistrée !");
        }
        return;
      }

      // Mobile natif
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        final taille = await photo.length();
        if (taille > _tailleMaxOctets) {
          _afficherAlerteTaille(taille);
          return;
        }
        final bytes = await photo.readAsBytes();
        setState(() {
          _documents[index].octets = bytes;
          _documents[index].nomFichier = photo.name.isNotEmpty ? photo.name : "doc_${_documents[index].typeKyc.toLowerCase()}.jpg";
          _documents[index].tailleOctets = taille;
        });
        _afficherSucces("Photo du document enregistrée !");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible d'accéder à l'appareil photo : ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _importerDepuisGalerieOuFichier(int index) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (files.isNotEmpty) {
        final f = files.first;
        final bytes = await f.readAsBytes();
        final size = bytes.lengthInBytes;

        if (size > _tailleMaxOctets) {
          _afficherAlerteTaille(size);
          return;
        }

        setState(() {
          _documents[index].octets = bytes;
          _documents[index].nomFichier = f.name;
          _documents[index].tailleOctets = size;
        });
        _afficherSucces("Document \"${f.name}\" importé avec succès !");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection : ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _supprimerDocument(int index) {
    setState(() {
      _documents[index].octets = null;
      _documents[index].nomFichier = null;
      _documents[index].tailleOctets = null;
    });
  }

  void _afficherAlerteTaille(int octets) {
    final mo = (octets / (1024 * 1024)).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Document trop volumineux"),
        content: Text("Le fichier fait $mo Mo. La limite autorisée est de 5 Mo."),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA67954)),
            child: const Text("Compris"),
          ),
        ],
      ),
    );
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _soumettreDossier() async {
    // Vérification des pièces obligatoires (Pièce d'identité, Justificatif d'activité, Identifiant NIF)
    final obligatoiresNonRenseignes = _documents.where((d) => d.obligatoire && !d.estRenseigne).toList();
    if (obligatoiresNonRenseignes.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text("Documents requis"),
            ],
          ),
          content: Text(
            "Veuillez photographier ou importer les pièces obligatoires suivantes avant de soumettre votre dossier :\n\n${obligatoiresNonRenseignes.map((d) => "• ${d.titre}").join("\n")}",
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA67954)),
              child: const Text("Compléter mon dossier"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final piecesAEnvoyer = _documents
          .where((d) => d.estRenseigne)
          .map((d) => PieceDocumentKyc(
                type: d.typeKyc,
                nomFichier: d.nomFichier ?? "doc_${d.typeKyc}.jpg",
                octets: d.octets!,
              ))
          .toList();

      await KycApiService.instance.soumettreDossier(pieces: piecesAEnvoyer);

      if (!mounted) return;

      // Redirection immédiate vers la page d'attente (Figma Frame 4)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => GrossisteEnAttenteScreen(
            nomGrossiste: widget.nomEntreprise,
            telephone: widget.telephone,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 26),
              SizedBox(width: 10),
              Text("Erreur d'envoi"),
            ],
          ),
          content: Text("Une erreur est survenue lors du téléversement : ${e.toString()}"),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA67954)),
              child: const Text("Fermer"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryCamel = Color(0xFFA67954);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryCamel, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          "Soumettre mes documents",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E1E24),
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pour valider votre compte, veuillez fournir les documents suivants :",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A786A),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // LISTE DES CARTES DE DOCUMENTS FIGMA
                  ...List.generate(_documents.length, (index) {
                    final doc = _documents[index];
                    return _buildDocumentCard(doc, index);
                  }),

                  const SizedBox(height: 12),

                  // BOUTON POINTILLÉ FIGMA : "+ Ajouter un document"
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _documents.add(
                            ElementDocumentAEnvoyer(
                              titre: "Document supplémentaire",
                              sousTitre: "PDF, JPG, PNG (max 5 Mo)",
                              typeKyc: "AUTRE",
                              obligatoire: false,
                              icone: Icons.note_add_outlined,
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 20, color: primaryCamel),
                      label: const Text(
                        "Ajouter un document",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryCamel,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: primaryCamel.withValues(alpha: 0.5),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // BOUTON PLEIN MARRON FIGMA : "Soumettre"
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _soumettreDossier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryCamel,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: primaryCamel.withValues(alpha: 0.3),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Soumettre",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // OVERLAY CHARGEMENT
          if (_isSubmitting)
            Container(
              color: Colors.black45,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primaryCamel),
                      SizedBox(height: 16),
                      Text(
                        "Envoi sécurisé de vos pièces légales...",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(ElementDocumentAEnvoyer doc, int index) {
    const primaryCamel = Color(0xFFA67954);
    final estRempli = doc.estRenseigne;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: estRempli ? AppTheme.success.withValues(alpha: 0.5) : const Color(0xFFEFE8E0),
          width: estRempli ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _ouvrirSelectionDocument(index),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icône circulaire caramel / verte
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: estRempli
                        ? AppTheme.success.withValues(alpha: 0.12)
                        : const Color(0xFFF3EAE1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    estRempli ? Icons.check_circle_rounded : doc.icone,
                    color: estRempli ? AppTheme.success : primaryCamel,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Titre et sous-titre
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc.titre,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E1E24),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (doc.obligatoire)
                            const Text(
                              " *",
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        estRempli
                            ? "${doc.nomFichier} (${((doc.tailleOctets ?? 0) / 1024).toStringAsFixed(0)} Ko)"
                            : doc.sousTitre,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: estRempli ? AppTheme.success : const Color(0xFF8A786A),
                          fontWeight: estRempli ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Bouton d'action (Prendre/Importer ou Supprimer)
                if (estRempli)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                    tooltip: "Retirer",
                    onPressed: () => _supprimerDocument(index),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryCamel.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 14, color: primaryCamel),
                        SizedBox(width: 4),
                        Text(
                          "Ajouter",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: primaryCamel,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
