import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/kyc_api_service.dart';
import '../theme/app_theme.dart';
import '../courtier/assistance_courtier_screen.dart';
import '../models/role_acteur.dart';
import 'assistance_grossiste_screen.dart';
import 'grossiste_onboarding_widgets.dart';
import '../services/visibilite_ecran.dart';

/// Espace verrouillé pendant l'examen du dossier d'un Grossiste ou d'un Courtier (maquette Figma « Espace Vendeur
/// Karavan »). Tirer vers le bas relit le dossier : approuvé → reconnexion puis espace, rejeté → nouveau dépôt.
class GrossisteDossierExamenScreen extends StatefulWidget {
  final DossierKyc dossier;
  final RoleActeur role;

  const GrossisteDossierExamenScreen({super.key, required this.dossier, this.role = RoleActeur.grossiste});

  @override
  State<GrossisteDossierExamenScreen> createState() => _GrossisteDossierExamenScreenState();
}

class _GrossisteDossierExamenScreenState extends State<GrossisteDossierExamenScreen> {
  late DossierKyc _dossier = widget.dossier;
  bool _estValide = false;
  Timer? _timerVerif;
  bool _dialogAffiche = false;

  static const _libellesTypes = {
    'PIECE_IDENTITE': "Pièce d'identité",
    'REGISTRE_COMMERCE': "Registre de commerce (RCCM)",
    'NIF': "Attestation NIF",
    'LICENCE_TRANSIT': "Licence de transitaire",
    'RELEVE_BANCAIRE': "Relevé bancaire",
    'AUTRE': "Document complémentaire",
  };

  bool get _courtier => widget.role == RoleActeur.courtier;
  bool get _commercant => widget.role == RoleActeur.commercant;

  /// Écran de dépôt du dossier (rejet → nouveau dépôt), déclaré dans main.dart
  String get _routeDepot => switch (widget.role) {
    RoleActeur.courtier => '/courtier/kyc',
    RoleActeur.commercant => '/commercant/kyc',
    RoleActeur.grossiste => '/grossiste/kyc',
  };

  @override
  void initState() {
    super.initState();
    if (widget.role == RoleActeur.commercant) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/commercant');
      });
      return;
    }
    _estValide = _dossier.statut == 'APPROUVE';
    if (_estValide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _afficherNotificationValidation());
    } else {
      // Polling en temps réel toutes les 4 secondes pour détecter la validation de l'administrateur
      _timerVerif = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted && ecranVisible(context)) _verifierStatutAutomatique();
      });
    }
  }

  @override
  void dispose() {
    _timerVerif?.cancel();
    super.dispose();
  }

  Future<void> _verifierStatutAutomatique() async {
    try {
      final dossier = await KycApiService.instance.monDossier();
      if (!mounted || dossier == null) return;
      if (dossier.statut == 'APPROUVE' && !_estValide) {
        _timerVerif?.cancel();
        setState(() {
          _dossier = dossier;
          _estValide = true;
        });
        _afficherNotificationValidation();
      } else if (dossier.statut == 'REJETE') {
        _timerVerif?.cancel();
        Navigator.of(context).pushNamedAndRemoveUntil(
          _routeDepot,
          (route) => route.isFirst,
          arguments: dossier.motifRejet,
        );
      }
    } catch (_) {}
  }

  void _afficherNotificationValidation() {
    if (_dialogAffiche || !mounted) return;
    _dialogAffiche = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppTheme.couleurCarte(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.oliveClair,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_rounded, color: CouleursArrivee.vert, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _courtier
                    ? "Compte Courtier Validé !"
                    : (_commercant ? "Compte Commerçant Validé !" : "Compte Grossiste Validé !"),
                style: TextStyle(fontFamily: AppTheme.policeTitre, fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.couleurTexte(context)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _courtier
                  ? "Félicitations ! Votre dossier de courtier a été examiné et approuvé par l'équipe de conformité Karavan."
                  : (_commercant
                      ? "Félicitations ! Votre dossier commerçant a été examiné et approuvé par l'équipe de conformité Karavan."
                      : "Félicitations ! Votre dossier vendeur a été examiné et approuvé par l'équipe de conformité Karavan."),
              style: TextStyle(fontSize: 13.5, color: AppTheme.couleurTexte(context), height: 1.4, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              _courtier
                  ? "Votre pièce d'identité et votre licence de transitaire sont désormais certifiées. Vous pouvez dès à présent vous connecter pour accéder à votre espace courtier."
                  : (_commercant
                      ? "Votre pièce d'identité et votre justificatif de commerce sont certifiés. Vous pouvez désormais commander et participer aux achats groupés."
                      : "Toutes vos pièces légales (RCCM, NIF) sont désormais certifiées. Vous pouvez dès à présent vous connecter pour accéder à votre espace vendeur et commencer vos ventes."),
              style: const TextStyle(fontSize: 12.5, color: CouleursArrivee.texteDoux, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                _dialogAffiche = false;
                _redirigerVersConnexion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursArrivee.vert,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Continuer",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      _dialogAffiche = false;
    });
  }

  Future<void> _redirigerVersConnexion() async {
    _timerVerif?.cancel();
    final profil = await AuthService.instance.rechargerProfil().catchError((_) => null);
    if (!mounted) return;

    if (AuthService.instance.estConnecte && profil?.statut == 'ACTIF') {
      final espaceRoute = switch (widget.role) {
        RoleActeur.courtier => '/courtier',
        RoleActeur.commercant => '/commercant',
        RoleActeur.grossiste => '/grossiste',
      };
      Navigator.of(context).pushNamedAndRemoveUntil(espaceRoute, (route) => false);
      return;
    }

    await AuthService.instance.deconnecter();
    if (!mounted) return;
    final route = switch (widget.role) {
      RoleActeur.courtier => '/courtier/connexion',
      RoleActeur.commercant => '/commercant/connexion',
      RoleActeur.grossiste => '/grossiste/connexion',
    };
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  Future<void> _actualiser() async {
    try {
      final dossier = await KycApiService.instance.monDossier();
      if (!mounted || dossier == null) return;
      if (dossier.statut == 'APPROUVE') {
        _timerVerif?.cancel();
        setState(() {
          _dossier = dossier;
          _estValide = true;
        });
        _afficherNotificationValidation();
      } else if (dossier.statut == 'REJETE') {
        _timerVerif?.cancel();
        Navigator.of(context).pushNamedAndRemoveUntil(
          _routeDepot,
          (route) => route.isFirst,
          arguments: dossier.motifRejet,
        );
      } else {
        setState(() {
          _dossier = dossier;
          _estValide = false;
        });
      }
    } catch (e) {
      if (mounted) afficherErreur(context, e is ApiException ? e.messageComplet : "Actualisation impossible : $e");
    }
  }

  void _verrouille() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Disponible dès la validation de votre dossier"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _voirDocuments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.couleurCarte(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Dossier n° ${_dossier.id}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.couleurTexte(context)),
              ),
              const SizedBox(height: 10),
              for (final t in _dossier.typesDocuments)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: CouleursArrivee.vert, size: 20),
                  title: Text(_libellesTypes[t] ?? t),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _profil() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.couleurCarte(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.logout, color: AppTheme.danger),
          title: const Text("Se déconnecter"),
          onTap: () {
            AuthService.instance.deconnecter();
            Navigator.of(ctx).pop();
            Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == RoleActeur.commercant) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final nom = AuthService.instance.profilActuel?.nom ?? "Mon entreprise";
    final documents = _dossier.typesDocuments;
    final resume = [
      if (documents.contains('REGISTRE_COMMERCE')) "RCCM",
      if (documents.contains('NIF')) "NIF",
      if (documents.contains('LICENCE_TRANSIT')) "licence de transitaire",
      if (documents.contains('PIECE_IDENTITE')) "pièce d'identité",
    ].join(' & ');

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.olive,
          onRefresh: _actualiser,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            children: [
              // En-tête
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(color: CouleursArrivee.creme, shape: BoxShape.circle),
                        child: const Icon(Icons.home_rounded, color: AppTheme.primary, size: 24),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _estValide ? CouleursArrivee.vert : CouleursArrivee.ambre,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(
                            _estValide ? Icons.check : Icons.hourglass_bottom,
                            size: 9,
                            color: AppTheme.couleurCarte(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _courtier
                              ? "Espace Courtier Karavan"
                              : (_commercant ? "Espace Acheteur Karavan" : "Espace Vendeur Karavan"),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.couleurTexteAttenue(context)),
                        ),
                        Text(
                          nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.couleurCarte(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.couleurBordure(context)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications_none_rounded, size: 19, color: AppTheme.primary),
                        Positioned(
                          top: 7,
                          right: 8,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _estValide ? CouleursArrivee.vert : CouleursArrivee.ambre,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 38),

              // Carte d'état du dossier
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: _estValide ? AppTheme.oliveClair : AppTheme.ocreClair,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _estValide ? CouleursArrivee.vert : CouleursArrivee.ambre, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _estValide ? const Color(0x1434C759) : const Color(0x14E6A823),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _estValide ? AppTheme.oliveClair : AppTheme.ocreClair,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _estValide ? CouleursArrivee.vert : CouleursArrivee.ambre,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _estValide ? "DOSSIER APPROUVÉ & VALIDÉ" : "DOSSIER EN EXAMEN",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: _estValide ? AppTheme.oliveProfond : CouleursArrivee.ambreFonce,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _estValide ? "Statut : Actif" : "Délai : ~6 heures",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _estValide ? CouleursArrivee.vert : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _estValide ? "Félicitations ! Dossier validé" : "Vérification de vos pièces légales",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _estValide
                          ? (_courtier
                              ? "Votre compte courtier est activé avec succès. Vous pouvez désormais créer vos groupes d'achat et organiser vos convois en toute sécurité."
                              : "Votre compte vendeur est activé avec succès. Vous pouvez désormais publier vos produits, créer des groupes d'achat et encaisser vos paiements en toute sécurité.")
                          : (_courtier
                              ? "Votre pièce d'identité et votre licence de transitaire sont en cours d'audit par l'équipe conformité Karavan pour protéger les transactions du réseau."
                              : "Votre RCCM et NIF sont en cours d'audit par l'équipe conformité Karavan pour protéger les transactions du réseau."),
                      style: TextStyle(fontSize: 10.5, color: AppTheme.couleurTexteAttenue(context), height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: _estValide ? AppTheme.oliveBordure : AppTheme.ocreBordure),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const _Etape(numero: "1. Dépôt", etat: "Complet", couleur: CouleursArrivee.vert, icone: Icons.check),
                        const Expanded(child: _Liaison(couleur: CouleursArrivee.vert)),
                        _Etape(
                          numero: "2. Audit",
                          etat: _estValide ? "Validé" : "En cours...",
                          couleur: _estValide ? CouleursArrivee.vert : CouleursArrivee.ambre,
                          icone: _estValide ? Icons.check : Icons.circle,
                        ),
                        Expanded(
                          child: _Liaison(
                            couleur: _estValide ? CouleursArrivee.vert : AppTheme.bordure,
                            pointille: !_estValide,
                          ),
                        ),
                        _Etape(
                          numero: "3. Ventes",
                          etat: _estValide ? "Validé & Actif" : "Verrouillé",
                          couleur: _estValide ? CouleursArrivee.vert : CouleursArrivee.indice,
                          icone: _estValide ? Icons.check_circle_rounded : Icons.circle,
                          estompe: !_estValide,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_estValide) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _redirigerVersConnexion,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text(
                            "Accéder à mon espace",
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CouleursArrivee.vert,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                          ),
                        ),
                      ),
                    ] else
                      const Text(
                        "Vous recevrez une notification et un SMS dès validation définitive.",
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 44),

              Text(
                "Votre dossier & Assistance",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context)),
              ),
              const SizedBox(height: 12),
              _CarteAction(
                fond: Colors.white,
                bordure: AppTheme.bordure,
                icone: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppTheme.surfaceDouce, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.article_outlined, color: AppTheme.primary),
                ),
                titre: "Documents légaux soumis",
                couleurTitre: AppTheme.couleurTexte(context),
                ligne1: resume.isEmpty ? "${documents.length} pièce(s) enregistrée(s)" : "$resume enregistrés",
                couleurLigne1: CouleursArrivee.texteDoux,
                ligne2: "Aucune action requise",
                couleurLigne2: CouleursArrivee.vert,
                fleche: true,
                onTap: _voirDocuments,
              ),
              const SizedBox(height: 12),
              _CarteAction(
                fond: AppTheme.oliveClair,
                bordure: AppTheme.oliveBordure,
                icone: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: AppTheme.olive, shape: BoxShape.circle),
                  child: const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                ),
                titre: "Équipe d'intégration Karavan",
                couleurTitre: AppTheme.oliveProfond,
                ligne1: "Besoin d'accélérer la vérification de votre compte ?",
                couleurLigne1: AppTheme.oliveProfond,
                ligne2: "Échanger sur WhatsApp avec un agent à Bamako →",
                couleurLigne2: AppTheme.oliveProfond,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _courtier ? const AssistanceCourtierScreen() : const AssistanceGrossisteScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDouce,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.bordure),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 10,
                      backgroundColor: AppTheme.oliveClair,
                      child: Icon(Icons.check, size: 12, color: CouleursArrivee.vert),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "Engagement Karavan :\n",
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.couleurTexte(context), fontSize: 11),
                            ),
                            const TextSpan(text: "Votre catalogue sera immédiatement débloqué après validation."),
                          ],
                        ),
                        style: const TextStyle(fontSize: 10.5, color: CouleursArrivee.texteDoux),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BarreVerrouillee(onVerrouille: _verrouille, onProfil: _profil),
    );
  }
}

class _Etape extends StatelessWidget {
  final String numero;
  final String etat;
  final Color couleur;
  final IconData icone;
  final bool estompe;

  const _Etape({
    required this.numero,
    required this.etat,
    required this.couleur,
    required this.icone,
    this.estompe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: couleur.withValues(alpha: estompe ? 0.4 : 1), width: 1.2),
          ),
          child: Icon(icone, size: icone == Icons.circle ? 7 : 12, color: couleur.withValues(alpha: estompe ? 0.5 : 1)),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              numero,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: estompe ? CouleursArrivee.indice : AppTheme.couleurTexte(context),
              ),
            ),
            Text(
              etat,
              style: TextStyle(fontSize: 9, fontWeight: estompe ? FontWeight.w400 : FontWeight.w700, color: couleur),
            ),
          ],
        ),
      ],
    );
  }
}

class _Liaison extends StatelessWidget {
  final Color couleur;
  final bool pointille;

  const _Liaison({required this.couleur, this.pointille = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: pointille
          ? Row(
              children: List.generate(
                8,
                (i) => Expanded(child: Container(height: 1.5, color: i.isEven ? couleur : Colors.transparent)),
              ),
            )
          : Container(height: 1.8, color: couleur),
    );
  }
}

class _CarteAction extends StatelessWidget {
  final Color fond;
  final Color bordure;
  final Widget icone;
  final String titre;
  final Color couleurTitre;
  final String ligne1;
  final Color couleurLigne1;
  final String ligne2;
  final Color couleurLigne2;
  final bool fleche;
  final VoidCallback onTap;

  const _CarteAction({
    required this.fond,
    required this.bordure,
    required this.icone,
    required this.titre,
    required this.couleurTitre,
    required this.ligne1,
    required this.couleurLigne1,
    required this.ligne2,
    required this.couleurLigne2,
    required this.onTap,
    this.fleche = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fond,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bordure, width: 1.2),
          ),
          child: Row(
            children: [
              icone,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: couleurTitre)),
                    const SizedBox(height: 2),
                    Text(ligne1, style: TextStyle(fontSize: 11, color: couleurLigne1)),
                    const SizedBox(height: 2),
                    Text(ligne2, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: couleurLigne2)),
                  ],
                ),
              ),
              if (fleche) Icon(Icons.chevron_right, color: AppTheme.couleurTexte(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre de navigation : Produits, Groupes et le bouton central restent verrouillés jusqu'à la validation
class _BarreVerrouillee extends StatelessWidget {
  final VoidCallback onVerrouille;
  final VoidCallback onProfil;

  const _BarreVerrouillee({required this.onVerrouille, required this.onProfil});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            top: 12,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Color(0x0F2C241E), blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ItemNav(icone: Icons.home_rounded, libelle: "Accueil", actif: true, onTap: () {}),
                      _ItemNav(icone: Icons.inventory_2_outlined, libelle: "Produits", verrouille: true, onTap: onVerrouille),
                      const Spacer(),
                      _ItemNav(icone: Icons.groups_outlined, libelle: "Groupes", verrouille: true, onTap: onVerrouille),
                      _ItemNav(icone: Icons.person_outline, libelle: "Profil", onTap: onProfil),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: onVerrouille,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppTheme.bordure, shape: BoxShape.circle),
                child: const Icon(Icons.lock_rounded, color: AppTheme.textMuted, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final bool actif;
  final bool verrouille;
  final VoidCallback onTap;

  const _ItemNav({
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.actif = false,
    this.verrouille = false,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppTheme.primary : CouleursArrivee.texteDoux;
    return Expanded(
      flex: 2,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: verrouille ? 0.45 : 1,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icone, color: couleur, size: 22),
                  if (verrouille)
                    const Positioned(right: -6, top: -4, child: Icon(Icons.lock, size: 10, color: CouleursArrivee.texteDoux)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                libelle,
                style: TextStyle(fontSize: 10, fontWeight: actif ? FontWeight.w700 : FontWeight.w400, color: couleur),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
