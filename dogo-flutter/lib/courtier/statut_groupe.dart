import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Libellés et couleurs des statuts de groupe (enum StatutGroupe du backend)
class StatutGroupe {
  StatutGroupe._();

  static const filtres = <String, Set<String>>{
    "Tous": {},
    "Brouillons": {"BROUILLON"},
    "En validation": {"EN_VALIDATION"},
    "Ouverts": {"OUVERT"},
    "À acheminer": {"OBJECTIF_ATTEINT", "EN_EXPEDITION", "LIVRE"},
    "Clos": {"TERMINE", "ANNULE", "ECHOUE"},
  };

  static String libelle(String statut) => switch (statut) {
        "BROUILLON" => "Brouillon",
        "EN_VALIDATION" => "En validation",
        "OUVERT" => "Ouvert",
        "OBJECTIF_ATTEINT" => "Objectif atteint",
        "EN_EXPEDITION" => "En expédition",
        "LIVRE" => "Livré au dépôt",
        "TERMINE" => "Terminé",
        "ANNULE" => "Annulé",
        "ECHOUE" => "Échoué",
        _ => statut,
      };

  static Color couleur(String statut) => switch (statut) {
        "BROUILLON" => AppTheme.textMuted,
        "EN_VALIDATION" => const Color(0xFFB7791F),
        "OUVERT" => AppTheme.primary,
        "OBJECTIF_ATTEINT" || "EN_EXPEDITION" || "LIVRE" => const Color(0xFF2B6CB0),
        "TERMINE" => AppTheme.success,
        _ => const Color(0xFFC0392B),
      };

  /// RG-24 : annulation possible tant que le groupe est brouillon, en validation ou ouvert
  static bool annulable(String statut) =>
      const {"BROUILLON", "EN_VALIDATION", "OUVERT"}.contains(statut);

  static bool aAcheminer(String statut) => const {"OBJECTIF_ATTEINT", "EN_EXPEDITION", "LIVRE"}.contains(statut);

  static Widget badge(String statut) {
    final c = couleur(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
      child: Text(libelle(statut), style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11.5)),
    );
  }
}
