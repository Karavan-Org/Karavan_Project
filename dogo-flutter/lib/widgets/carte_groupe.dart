import 'package:flutter/material.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import 'image_produit.dart';

/// Carte d'un groupe d'achat (listes du courtier et du grossiste) : produit, statut, jauge, action éventuelle.
class CarteGroupe extends StatelessWidget {
  final GroupeResume groupe;

  /// Nom affiché sous le produit (le grossiste pour le courtier, le courtier pour le grossiste)
  final String partenaire;
  final Widget? action;

  const CarteGroupe({super.key, required this.groupe, required this.partenaire, this.action});

  static Color couleurStatut(String statut) => switch (statut) {
        'BROUILLON' => const Color(0xFF8C7E74),
        'EN_VALIDATION' => const Color(0xFFE6A823),
        'OUVERT' => const Color(0xFF2E7D32),
        'OBJECTIF_ATTEINT' || 'EN_EXPEDITION' || 'LIVRE' => const Color(0xFF1976D2),
        'ANNULE' || 'ECHOUE' => const Color(0xFFC0392B),
        _ => const Color(0xFF5A493B),
      };

  @override
  Widget build(BuildContext context) {
    final couleur = couleurStatut(groupe.statut);
    final ratio = groupe.ratioProgression;
    final piecesAffichees = groupe.quantiteProgression;
    final pourcentage = groupe.pourcentageProgression;
    final limite = groupe.dateLimite?.toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 58,
                  height: 58,
                  color: AppTheme.couleurSurfaceDouce(context),
                  child: imageProduit(groupe.photoUrl ?? '', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Groupe n° ${groupe.id}",
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.couleurAccent(context)),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: couleur.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              groupe.libelleStatut,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: couleur),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      groupe.titre.isNotEmpty ? groupe.titre : groupe.produitNom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.couleurTexte(context)),
                    ),
                    if (partenaire.isNotEmpty)
                      Text(partenaire, style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  "$piecesAffichees / ${groupe.quantiteCible} pièces réservées ($pourcentage%)",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.couleurTexte(context)),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "${groupe.prixUnitaire} FCFA / pce",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.couleurAccent(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: AppTheme.couleurBordure(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                groupe.aAtteint100 ? const Color(0xFF2E7D32) : couleur,
              ),
            ),
          ),
          if (limite != null) ...[
            const SizedBox(height: 6),
            Text(
              "Date limite : ${limite.day.toString().padLeft(2, '0')}/${limite.month.toString().padLeft(2, '0')}/${limite.year}",
              style: TextStyle(fontSize: 11, color: AppTheme.couleurTexteAttenue(context)),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
