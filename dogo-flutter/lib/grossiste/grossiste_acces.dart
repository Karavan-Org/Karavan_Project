import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/kyc_api_service.dart';
import 'grossiste_documents_kyc_screen.dart';
import 'grossiste_dossier_examen_screen.dart';
import 'grossiste_main_nav.dart';

/// Écran d'arrivée d'un grossiste connecté selon l'état de son compte (RG-03 à RG-05) :
/// compte actif → espace vendeur ; sinon dépôt du dossier, ou suivi de l'examen en cours.
Future<Widget> ecranGrossisteSelonDossier(UtilisateurProfil profil) async {
  if (profil.statut == 'ACTIF') return const GrossisteMainNav();

  final dossier = await KycApiService.instance.monDossier();
  if (dossier == null) return const GrossisteDocumentsKycScreen();
  return switch (dossier.statut) {
    'APPROUVE' => const GrossisteMainNav(),
    'REJETE' => GrossisteDocumentsKycScreen(motifRejet: dossier.motifRejet),
    _ => GrossisteDossierExamenScreen(dossier: dossier),
  };
}
