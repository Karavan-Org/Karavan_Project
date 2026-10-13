import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/kyc_api_service.dart';
import '../theme/app_theme.dart';
import 'assistance_grossiste_screen.dart';
import 'grossiste_onboarding_widgets.dart';

/// Espace vendeur verrouillé pendant l'examen du dossier (maquette Figma « Espace Vendeur dɔgɔ »).
/// Tirer vers le bas relit le dossier : approuvé → espace vendeur, rejeté → nouveau dépôt.
class GrossisteDossierExamenScreen extends StatefulWidget {
  final DossierKyc dossier;

  const GrossisteDossierExamenScreen({super.key, required this.dossier});

  @override
  State<GrossisteDossierExamenScreen> createState() => _GrossisteDossierExamenScreenState();
}

class _GrossisteDossierExamenScreenState extends State<GrossisteDossierExamenScreen> {
  late DossierKyc _dossier = widget.dossier;

  static const _libellesTypes = {
    'PIECE_IDENTITE': "Pièce d'identité",
    'REGISTRE_COMMERCE': "Registre de commerce (RCCM)",
    'NIF': "Attestation NIF",
    'RELEVE_BANCAIRE': "Relevé bancaire",
    'AUTRE': "Document complémentaire",
  };

  Future<void> _actualiser() async {
    try {
      final dossier = await KycApiService.instance.monDossier();
      if (!mounted || dossier == null) return;
      if (dossier.statut == 'APPROUVE') {
        Navigator.of(context).pushNamedAndRemoveUntil('/grossiste', (route) => route.isFirst);
      } else if (dossier.statut == 'REJETE') {
        Navigator.of(context).pushNamedAndRemoveUntil('/grossiste/kyc', (route) => route.isFirst, arguments: dossier.motifRejet);
      } else {
        setState(() => _dossier = dossier);
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
      backgroundColor: Colors.white,
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CouleursArrivee.titre),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.logout, color: Color(0xFFC0392B)),
          title: const Text("Se déconnecter"),
          onTap: () {
            AuthService.instance.deconnecter();
            Navigator.of(ctx).pop();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nom = AuthService.instance.profilActuel?.nom ?? "Mon entreprise";
    final documents = _dossier.typesDocuments;
    final resume = [
      if (documents.contains('REGISTRE_COMMERCE')) "RCCM",
      if (documents.contains('NIF')) "NIF",
      if (documents.contains('PIECE_IDENTITE')) "pièce d'identité",
    ].join(' & ');

    return Scaffold(
      backgroundColor: CouleursArrivee.fond,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.primary,
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
                            color: CouleursArrivee.ambre,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.hourglass_bottom, size: 9, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Espace Vendeur dɔgɔ",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CouleursArrivee.texteDoux),
                        ),
                        Text(
                          nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CouleursArrivee.titre),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEDE7E1)),
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
                            decoration: const BoxDecoration(color: CouleursArrivee.ambre, shape: BoxShape.circle),
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
                  color: const Color(0xFFFFFCF5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CouleursArrivee.ambre, width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x14EEA823), blurRadius: 14, offset: Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEFC7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(color: CouleursArrivee.ambre, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "DOSSIER EN EXAMEN",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: CouleursArrivee.ambreFonce,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          "Délai : ~6 heures",
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Vérification de vos pièces légales",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CouleursArrivee.titre),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Votre RCCM et NIF sont en cours d'audit par l'équipe conformité dɔgɔ pour protéger "
                      "les transactions du réseau.",
                      style: TextStyle(fontSize: 10.5, color: CouleursArrivee.texteDoux, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1E4CF)),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        _Etape(numero: "1. Dépôt", etat: "Complet", couleur: CouleursArrivee.vert, icone: Icons.check),
                        Expanded(child: _Liaison(couleur: CouleursArrivee.vert)),
                        _Etape(
                          numero: "2. Audit",
                          etat: "En cours...",
                          couleur: CouleursArrivee.ambre,
                          icone: Icons.circle,
                        ),
                        Expanded(child: _Liaison(couleur: Color(0xFFE5DED7), pointille: true)),
                        _Etape(
                          numero: "3. Ventes",
                          etat: "Verrouillé",
                          couleur: CouleursArrivee.indice,
                          icone: Icons.circle,
                          estompe: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "🔔 Vous recevrez une notification et un SMS dès validation définitive.",
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 44),

              const Text(
                "Votre dossier & Assistance",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CouleursArrivee.titre),
              ),
              const SizedBox(height: 12),
              _CarteAction(
                fond: Colors.white,
                bordure: const Color(0xFFEDE7E1),
                icone: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: const Color(0xFFF7EFE6), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.article_outlined, color: AppTheme.primary),
                ),
                titre: "Documents légaux soumis",
                couleurTitre: CouleursArrivee.titre,
                ligne1: resume.isEmpty ? "${documents.length} pièce(s) enregistrée(s)" : "$resume enregistrés",
                couleurLigne1: CouleursArrivee.texteDoux,
                ligne2: "✓ Aucune action requise",
                couleurLigne2: CouleursArrivee.vert,
                fleche: true,
                onTap: _voirDocuments,
              ),
              const SizedBox(height: 12),
              _CarteAction(
                fond: const Color(0xFFF0FDF4),
                bordure: const Color(0xFFBBF7D0),
                icone: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                  child: const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                ),
                titre: "Équipe d'intégration dɔgɔ",
                couleurTitre: const Color(0xFF14532D),
                ligne1: "Besoin d'accélérer la vérification de votre compte ?",
                couleurLigne1: const Color(0xFF166534),
                ligne2: "Échanger sur WhatsApp avec un agent à Bamako →",
                couleurLigne2: const Color(0xFF15803D),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AssistanceGrossisteScreen()),
                ),
              ),
              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF3EC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1E4D8)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(0xFFD1FAE5),
                      child: Icon(Icons.check, size: 12, color: CouleursArrivee.vert),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "Engagement dɔgɔ :\n",
                              style: TextStyle(fontWeight: FontWeight.w700, color: CouleursArrivee.titre, fontSize: 11),
                            ),
                            TextSpan(text: "Votre catalogue sera immédiatement débloqué après validation."),
                          ],
                        ),
                        style: TextStyle(fontSize: 10.5, color: CouleursArrivee.texteDoux),
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
          child: Icon(icone, size: icone == Icons.check ? 12 : 7, color: couleur.withValues(alpha: estompe ? 0.5 : 1)),
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
                color: estompe ? CouleursArrivee.indice : CouleursArrivee.titre,
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
              if (fleche) const Icon(Icons.chevron_right, color: CouleursArrivee.titre),
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
                boxShadow: [BoxShadow(color: Color(0x0F2D231C), blurRadius: 16, offset: Offset(0, -4))],
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
                decoration: const BoxDecoration(color: Color(0xFFEDE4DA), shape: BoxShape.circle),
                child: const Icon(Icons.lock_rounded, color: Color(0xFF7C6E65), size: 22),
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
