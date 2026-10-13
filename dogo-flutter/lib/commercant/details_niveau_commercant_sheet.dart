import 'package:flutter/material.dart';
import '../models/niveau_commercant.dart';
import '../widgets/tab_navigation_scope.dart';


/// Modal présentant les détails du niveau du Commerçant, sa progression
/// et les avantages débloqués / à débloquer selon le volume de commandes.
class DetailsNiveauCommercantSheet extends StatelessWidget {
  final int nbCommandes;
  final NiveauCommercant niveau;

  const DetailsNiveauCommercantSheet({
    super.key,
    required this.nbCommandes,
    required this.niveau,
  });

  /// Méthode d'ouverture conviviale
  static Future<void> afficher(
    BuildContext context, {
    required int nbCommandes,
  }) {
    final niveau = NiveauCommercant.calculer(nbCommandes);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DetailsNiveauCommercantSheet(
        nbCommandes: nbCommandes,
        niveau: niveau,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int restantes = niveau.commandesRestantesPourSuivant(nbCommandes);
    final int pourcentage = niveau.pourcentageProgression(nbCommandes);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée supérieure de glissement
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFD6CBC0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // En-tête avec bouton de fermeture
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Niveau Commerçant",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C241E),
                    letterSpacing: -0.2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF2C241E), size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: "Fermer",
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEFE9E0)),

          // Contenu défilable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CARTE PRINCIPALE DU NIVEAU ACTUEL ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFEFE9E0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A46321E),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Pastille / Badge grand format
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: niveau.couleurBadge.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: niveau.couleurBadge.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            niveau.icone,
                            size: 34,
                            color: niveau.couleurBadge,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Titre & Sous-titre
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: niveau.couleurBadge,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                niveau.titre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              niveau.sousTitre,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2C241E),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Text(
                          niveau.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF7A6B60),
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFF2ECE4)),
                        const SizedBox(height: 16),

                        // --- BARRE DE PROGRESSION ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                niveau.seuilSuivant != null
                                    ? "Progression vers le ${niveau.nomNiveauSuivant}"
                                    : "Statut VIP maximal atteint",
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C241E),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$pourcentage%",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: niveau.couleurBadge,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: niveau.progression(nbCommandes),
                            minHeight: 10,
                            backgroundColor: const Color(0xFFEFE9E0),
                            valueColor: AlwaysStoppedAnimation<Color>(niveau.couleurBadge),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                "$nbCommandes commande(s) réalisée(s)",
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8C7E74),
                                ),
                              ),
                            ),
                            if (niveau.seuilSuivant != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Objectif : ${niveau.seuilSuivant} commandes",
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8C7E74),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (niveau.seuilSuivant != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF2EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.flag_rounded,
                                  size: 16,
                                  color: Color(0xFF9E6738),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Plus que $restantes commande(s) pour atteindre le ${niveau.nomNiveauSuivant} !",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9E6738),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // --- RÈGLE DES 3 PALIERS (TRANSPARENCE TOTALE) ---
                  const Text(
                    "Paliers de fidélité DoGo",
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C241E),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _buildPalierTile(
                    niveau: NiveauCommercant.niveau1,
                    estActuel: niveau == NiveauCommercant.niveau1,
                    fourchette: "1 à 4 commandes",
                    resume: "Débutant • Découverte des prix usine et sécurisation séquestre",
                  ),

                  const SizedBox(height: 8),

                  _buildPalierTile(
                    niveau: NiveauCommercant.niveau2,
                    estActuel: niveau == NiveauCommercant.niveau2,
                    fourchette: "5 à 19 commandes",
                    resume: "Régulier • Badge vérifié & priorité sur les arrivages",
                  ),

                  const SizedBox(height: 8),

                  _buildPalierTile(
                    niveau: NiveauCommercant.niveau3,
                    estActuel: niveau == NiveauCommercant.niveau3,
                    fourchette: "20 commandes et +",
                    resume: "VIP • Sourcing sur-mesure d'usines & facilités de règlement",
                  ),

                  const SizedBox(height: 22),

                  // --- AVANTAGES ACTUELS (DÉBLOQUÉS) ---
                  Text(
                    "Avantages débloqués (${niveau.titre})",
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C241E),
                    ),
                  ),

                  const SizedBox(height: 10),

                  ...niveau.avantages.map((a) => _buildAvantageItem(
                        texte: a,
                        debloque: true,
                        couleur: niveau.couleurBadge,
                      )),

                  if (niveau.avantagesSuivants.isNotEmpty) ...[
                    const SizedBox(height: 20),

                    // --- PROCHAINS AVANTAGES À DÉBLOQUER ---
                    Text(
                      "À débloquer au ${niveau.nomNiveauSuivant}",
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C241E),
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...niveau.avantagesSuivants.map((a) => _buildAvantageItem(
                          texte: a,
                          debloque: false,
                          couleur: const Color(0xFF9E6738),
                        )),
                  ],

                  const SizedBox(height: 24),

                  // --- BOUTON D'ACTION : DÉCOUVRIR LES GROUPES ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        TabNavigationScope.switchToTab(context, 0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2832),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Explorer les groupes d'achat",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tuile d'un palier
  Widget _buildPalierTile({
    required NiveauCommercant niveau,
    required bool estActuel,
    required String fourchette,
    required String resume,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: estActuel ? Colors.white : const Color(0xFFF3ECE3).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: estActuel ? niveau.couleurBadge : const Color(0xFFE8DFD4),
          width: estActuel ? 1.6 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: niveau.couleurBadge,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              niveau.titre,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        fourchette,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C241E),
                        ),
                      ),
                    ),
                    if (estActuel) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Votre niveau",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  resume,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF7A6B60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Élément d'avantage
  Widget _buildAvantageItem({
    required String texte,
    required bool debloque,
    required Color couleur,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            debloque ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 18,
            color: debloque ? const Color(0xFF2E7D32) : const Color(0xFFB0A294),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: debloque ? FontWeight.w600 : FontWeight.w500,
                color: debloque ? const Color(0xFF2C241E) : const Color(0xFF8C7E74),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
