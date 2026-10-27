import 'package:flutter/material.dart';
import '../commercant/commercant_main_nav.dart';
import '../courtier/courtier_main_nav.dart';
import '../models/role_acteur.dart';
import '../services/auth_service.dart';
import '../services/kyc_api_service.dart';
import 'grossiste_documents_kyc_screen.dart';
import 'grossiste_dossier_examen_screen.dart';
import 'grossiste_main_nav.dart';

/// Écran d'arrivée d'un Grossiste ou d'un Courtier connecté selon l'état de son compte (RG-03 à RG-05) :
/// compte actif → son espace ; sinon dépôt du dossier, nouveau dépôt après rejet, ou suivi de l'examen.
///
/// Le statut est relu sur le serveur : un profil local périmé ne doit ni ouvrir l'espace à un compte en
/// attente, ni bloquer un compte qui vient d'être validé. Le serveur refuse de toute façon (403) les actions
/// d'un compte en attente : cet aiguillage évite seulement de lui montrer un espace inutilisable.
Future<Widget> ecranSelonStatut(UtilisateurProfil profil, RoleActeur role) async {
  final Widget espace = switch (role) {
    RoleActeur.courtier => const CourtierMainNav(),
    RoleActeur.grossiste => const GrossisteMainNav(),
    RoleActeur.commercant => const CommercantMainNav(),
  };
  final actuel = await AuthService.instance.rechargerProfil().catchError((_) => null) ?? profil;
  if (actuel.statut == 'ACTIF') return espace;

  final dossier = await KycApiService.instance.monDossier();
  if (dossier == null) return GrossisteDocumentsKycScreen(role: role);
  return switch (dossier.statut) {
    'REJETE' => GrossisteDocumentsKycScreen(role: role, motifRejet: dossier.motifRejet),
    _ => GrossisteDossierExamenScreen(dossier: dossier, role: role),
  };
}

/// Variante historique pour le Grossiste.
Future<Widget> ecranGrossisteSelonDossier(UtilisateurProfil profil) => ecranSelonStatut(profil, RoleActeur.grossiste);

/// Garde des espaces Grossiste et Courtier : quelle que soit la façon d'y arriver (lien web, session
/// restaurée, bouton), un compte qui n'est pas actif est renvoyé vers son parcours de vérification.
class GardeCompteActif extends StatefulWidget {
  final RoleActeur role;
  final Widget child;

  const GardeCompteActif({super.key, required this.role, required this.child});

  @override
  State<GardeCompteActif> createState() => _GardeCompteActifState();
}

class _GardeCompteActifState extends State<GardeCompteActif> {
  bool _redirection = false;

  bool get _enAttente {
    final statut = AuthService.instance.profilActuel?.statut;
    return statut != null && statut != 'ACTIF';
  }

  /// Un compte d'un autre rôle (lien web, ancien bouton…) n'a rien à faire dans cet espace
  bool get _autreRole {
    final profil = AuthService.instance.profilActuel;
    return profil != null && profil.roleActeur != widget.role;
  }

  @override
  void initState() {
    super.initState();
    if (_autreRole) {
      _redirection = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _renvoyerVersSonEspace());
    } else if (_enAttente) {
      _redirection = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _rediriger());
    }
  }

  void _renvoyerVersSonEspace() {
    if (!mounted) return;
    final route = switch (AuthService.instance.profilActuel?.roleActeur) {
      RoleActeur.grossiste => '/grossiste',
      RoleActeur.courtier => '/courtier',
      _ => '/commercant',
    };
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  Future<void> _rediriger() async {
    final profil = AuthService.instance.profilActuel;
    if (profil == null) return;
    Widget destination;
    try {
      destination = await ecranSelonStatut(profil, widget.role);
    } catch (_) {
      // Statut illisible (réseau) : l'espace reste fermé, l'acteur repasse par son dépôt de dossier
      destination = GrossisteDocumentsKycScreen(role: widget.role);
    }
    if (!mounted) return;
    if (AuthService.instance.profilActuel?.statut == 'ACTIF') {
      setState(() => _redirection = false); // validé entre-temps : l'espace s'ouvre
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => destination), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Pendant la vérification, l'espace n'est pas construit (ses écrans appelleraient l'API pour rien)
    if (_redirection) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return widget.child;
  }
}
