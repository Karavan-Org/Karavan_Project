import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../models/role_acteur.dart';
import '../services/kyc_api_service.dart';
import '../theme/app_theme.dart';
import 'grossiste_dossier_examen_screen.dart';
import 'grossiste_onboarding_widgets.dart';
import 'selecteur_piece.dart';

/// Dépôt du dossier de vérification (maquette Figma « Soumettre mes documents ») d'un Grossiste ou d'un
/// Courtier : leur compte reste en attente, sans accès à leur espace, tant que le dossier n'est pas approuvé.
/// Chaque pièce peut être photographiée ou importée ; l'envoi part en un seul POST /api/kyc.
class GrossisteDocumentsKycScreen extends StatefulWidget {
  /// Motif du rejet précédent, affiché pour que l'acteur corrige son dossier
  final String? motifRejet;

  /// Grossiste ou Courtier : fixe les pièces demandées (TypeDocument.obligatoiresPour côté backend)
  final RoleActeur role;

  const GrossisteDocumentsKycScreen({super.key, this.motifRejet, this.role = RoleActeur.grossiste});

  @override
  State<GrossisteDocumentsKycScreen> createState() => _GrossisteDocumentsKycScreenState();
}

class _EmplacementPiece {
  final TypeDocumentKyc type;
  final String titre;
  final IconData icone;
  final bool obligatoire;

  const _EmplacementPiece(this.type, this.titre, this.icone, {this.obligatoire = false});
}

class _GrossisteDocumentsKycScreenState extends State<GrossisteDocumentsKycScreen> {
  static const _emplacementsGrossiste = [
    _EmplacementPiece(TypeDocumentKyc.pieceIdentite, "Pièce d'identité / Passeport", Icons.badge_outlined,
        obligatoire: true),
    _EmplacementPiece(TypeDocumentKyc.registreCommerce, "Justificatif d'activité (extrait, registre)",
        Icons.description_outlined,
        obligatoire: true),
    _EmplacementPiece(TypeDocumentKyc.nif, "Attestation NIF", Icons.receipt_long_outlined, obligatoire: true),
    _EmplacementPiece(TypeDocumentKyc.releveBancaire, "Relevé bancaire", Icons.shield_outlined),
    _EmplacementPiece(TypeDocumentKyc.autre, "Autres documents (optionnel)", Icons.workspace_premium_outlined),
  ];

  static const _emplacementsCourtier = [
    _EmplacementPiece(TypeDocumentKyc.pieceIdentite, "Pièce d'identité / Passeport", Icons.badge_outlined,
        obligatoire: true),
    _EmplacementPiece(TypeDocumentKyc.licenceTransit, "Licence de transitaire / commissionnaire",
        Icons.local_shipping_outlined,
        obligatoire: true),
    _EmplacementPiece(TypeDocumentKyc.releveBancaire, "Relevé bancaire", Icons.shield_outlined),
    _EmplacementPiece(TypeDocumentKyc.autre, "Autres documents (optionnel)", Icons.workspace_premium_outlined),
  ];

  static const _emplacementsCommercant = [
    _EmplacementPiece(TypeDocumentKyc.pieceIdentite, "Pièce d'identité (CNI / Passeport / NINA)", Icons.badge_outlined,
        obligatoire: true),
    _EmplacementPiece(TypeDocumentKyc.registreCommerce, "Justificatif de commerce (RCCM, déclaration boutique)",
        Icons.storefront_outlined,
        obligatoire: true),
    _EmplacementPiece(TypeDocumentKyc.nif, "Attestation NIF (si assujetti)", Icons.receipt_long_outlined),
    _EmplacementPiece(TypeDocumentKyc.autre, "Photo boutique / Autre document (optionnel)", Icons.workspace_premium_outlined),
  ];

  List<_EmplacementPiece> get _emplacements => switch (widget.role) {
    RoleActeur.courtier => _emplacementsCourtier,
    RoleActeur.commercant => _emplacementsCommercant,
    RoleActeur.grossiste => _emplacementsGrossiste,
  };

  String get _titrePage => switch (widget.role) {
    RoleActeur.courtier => "Dossier Courtier - Documents requis",
    RoleActeur.commercant => "Dossier Commerçant - Documents requis",
    RoleActeur.grossiste => "Dossier Grossiste - Documents requis",
  };

  String get _sousTitrePage => switch (widget.role) {
    RoleActeur.courtier => "Pour valider votre statut de courtier agréé, veuillez fournir les pièces suivantes.",
    RoleActeur.commercant => "Pour sécuriser vos achats groupés et valider votre compte commerçant, veuillez fournir les pièces suivantes.",
    RoleActeur.grossiste => "Pour valider votre compte grossiste partenaire, veuillez fournir les pièces suivantes.",
  };

  /// Une pièce par emplacement, plus les documents ajoutés via « Ajouter un document »
  final Map<TypeDocumentKyc, FichierChoisi> _pieces = {};
  final List<FichierChoisi> _supplementaires = [];
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == RoleActeur.commercant) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/commercant');
      });
    }
  }

  Future<void> _choisir(_EmplacementPiece e) async {
    final fichier = await choisirPiece(context, titre: e.titre);
    if (fichier != null) setState(() => _pieces[e.type] = fichier);
  }

  Future<void> _ajouterDocument() async {
    final fichier = await choisirPiece(context, titre: "Ajouter un document");
    if (fichier != null) setState(() => _supplementaires.add(fichier));
  }

  Future<void> _soumettre() async {
    if (!AuthService.instance.estConnecte) {
      afficherErreur(context, "Vous devez être connecté pour soumettre votre dossier. Veuillez vous connecter.");
      return;
    }

    final manquants = _emplacements.where((e) => e.obligatoire && !_pieces.containsKey(e.type)).toList();
    if (manquants.isNotEmpty) {
      afficherErreur(context, "Pièces obligatoires manquantes :\n• ${manquants.map((e) => e.titre).join('\n• ')}");
      return;
    }

    final pieces = [
      for (final e in _emplacements)
        if (_pieces[e.type] case final f?) PieceKyc(type: e.type, nomFichier: f.nom, octets: f.octets),
      for (final f in _supplementaires) PieceKyc(type: TypeDocumentKyc.autre, nomFichier: f.nom, octets: f.octets),
    ];

    setState(() => _envoi = true);
    try {
      final dossier = await KycApiService.instance.soumettre(pieces);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => GrossisteDossierExamenScreen(dossier: dossier, role: widget.role)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        afficherErreur(context, "Votre session a expiré. Veuillez vous reconnecter pour soumettre votre dossier.");
        return;
      }
      if (e is ApiException && e.statusCode == 409) {
        // Le dossier a déjà été soumis : on redirige vers l'écran d'examen
        final dossierExistant = await KycApiService.instance.monDossier();
        if (!mounted) return;
        if (dossierExistant != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => GrossisteDossierExamenScreen(dossier: dossierExistant, role: widget.role)),
            (route) => route.isFirst,
          );
          return;
        }
      }
      if (!mounted) return;
      afficherErreur(context, e is ApiException ? e.messageComplet : "Envoi impossible : $e");
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == RoleActeur.commercant) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (Navigator.of(context).canPop())
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(Icons.arrow_back, color: AppTheme.couleurTexte(context), size: 24),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _titrePage,
                      style: TextStyle(fontFamily: AppTheme.policeTitre, fontSize: 18.5, fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _sousTitrePage,
                style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context), height: 1.35),
              ),
              if (widget.motifRejet != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerClair,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dangerBordure),
                  ),
                  child: Text(
                    "Dossier précédent refusé : ${widget.motifRejet}",
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.dangerProfond, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              for (final e in _emplacements) ...[
                _CartePiece(
                  emplacement: e,
                  fichier: _pieces[e.type],
                  onTap: _envoi ? null : () => _choisir(e),
                  onRetirer: () => setState(() => _pieces.remove(e.type)),
                ),
                const SizedBox(height: 12),
              ],
              for (final (i, f) in _supplementaires.indexed) ...[
                _CartePiece(
                  emplacement: const _EmplacementPiece(TypeDocumentKyc.autre, "Document complémentaire",
                      Icons.attach_file),
                  fichier: f,
                  onTap: null,
                  onRetirer: () => setState(() => _supplementaires.removeAt(i)),
                ),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _envoi ? null : _ajouterDocument,
                child: CustomPaint(
                  painter: const BordurePointillee(),
                  child: Container(
                    height: 86,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.creme,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_upload_outlined, color: AppTheme.primary, size: 26),
                        SizedBox(height: 8),
                        Text(
                          "Ajouter un document",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 38),
              BoutonArrivee(libelle: "Soumettre", chargement: _envoi, onPressed: _soumettre),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartePiece extends StatelessWidget {
  final _EmplacementPiece emplacement;
  final FichierChoisi? fichier;
  final VoidCallback? onTap;
  final VoidCallback onRetirer;

  const _CartePiece({required this.emplacement, required this.fichier, required this.onTap, required this.onRetirer});

  @override
  Widget build(BuildContext context) {
    final f = fichier;
    final ko = f == null ? 0 : (f.octets.lengthInBytes / 1024).ceil();
    return Material(
      color: AppTheme.couleurCarte(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: f != null ? CouleursArrivee.vert : AppTheme.couleurBordure(context), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(emplacement.icone, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: emplacement.titre,
                        children: [
                          if (emplacement.obligatoire)
                            const TextSpan(text: ' *', style: TextStyle(color: AppTheme.primary)),
                        ],
                      ),
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f == null ? "PDF, image, Word, Excel, texte (max 5 Mo)" : "${f.nom} • $ko Ko",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: f == null ? AppTheme.couleurTexteAttenue(context) : CouleursArrivee.vert,
                        fontWeight: f == null ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (f != null)
                IconButton(
                  tooltip: "Retirer",
                  icon: Icon(Icons.close, size: 18, color: AppTheme.couleurTexteAttenue(context)),
                  onPressed: onRetirer,
                )
              else
                Icon(Icons.add_a_photo_outlined, size: 18, color: AppTheme.couleurTexteAttenue(context)),
            ],
          ),
        ),
      ),
    );
  }
}
