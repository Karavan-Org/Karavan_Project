import '../widgets/image_produit.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'campagne_model.dart';
import 'favoris_service.dart';
import 'rejoindre_groupe_screen.dart';

/// Fiche détaillée d'une campagne d'achat groupé pour le Commerçant
class FicheCampagneScreen extends StatefulWidget {
  final String id;
  final String titre;
  final String sousTitre;
  final String imagePath;
  final int prixGroupe;
  final int prixPublic;
  final int quantiteActuelle;
  final int quantiteObjectif;
  final String categorie;
  final String paysOrigine;
  final String courtierNom;
  final String tempsRestant;

  const FicheCampagneScreen({
    super.key,
    this.id = "",
    this.titre = "",
    this.sousTitre = "",
    this.imagePath = "",
    this.prixGroupe = 0,
    this.prixPublic = 0,
    this.quantiteActuelle = 0,
    this.quantiteObjectif = 1,
    this.categorie = "",
    this.paysOrigine = "",
    this.courtierNom = "",
    this.tempsRestant = "",
  });

  @override
  State<FicheCampagneScreen> createState() => _FicheCampagneScreenState();
}

class _FicheCampagneScreenState extends State<FicheCampagneScreen> {
  int _quantite = 2;
  String _tailleSelectionnee = "42";
  final List<String> _tailles = ["40", "41", "42", "43", "44"];

  double get _pourcentage =>
      (widget.quantiteActuelle / widget.quantiteObjectif).clamp(0.0, 1.0);

  int get _reste => widget.quantiteObjectif - widget.quantiteActuelle;

  @override
  Widget build(BuildContext context) {
    final economie = widget.prixPublic - widget.prixGroupe;
    final pourcentageEconomie = ((economie / widget.prixPublic) * 100).round();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // AppBar avec image produit grand format
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.textPrimary,
                leadingWidth: 72,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 6, bottom: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4C5B9), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark, size: 22),
                      tooltip: "Retour aux opportunités",
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: FavorisService.instance.favorisNotifier,
                  builder: (context, favoris, _) {
                    final isFav = favoris.contains(widget.id);
                    return CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : AppTheme.textPrimary,
                          size: 20,
                        ),
                        onPressed: () {
                          final model = GroupeCampagneModel(
                            id: widget.id,
                            titre: widget.titre,
                            sousTitre: widget.sousTitre,
                            imagePath: widget.imagePath,
                            prixGroupe: widget.prixGroupe,
                            prixPublic: widget.prixPublic,
                            quantiteActuelle: widget.quantiteActuelle,
                            quantiteObjectif: widget.quantiteObjectif,
                            categorie: widget.categorie,
                            paysOrigine: widget.paysOrigine,
                            courtierNom: widget.courtierNom,
                            tempsRestant: widget.tempsRestant,
                          );
                          FavorisService.instance.toggleFavori(model, context);
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Lien du groupe partagé dans le presse-papiers !"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF7F2EC),
                    child: Center(
                      child: imageProduit(
                        widget.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.shopping_bag_outlined,
                          size: 100,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  // Badge Promo économie
                  Positioned(
                    bottom: 16,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 8),
                        ],
                      ),
                      child: Text(
                        "-$pourcentageEconomie% EN ACHAT GROUPÉ",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Badge temps restant
                  Positioned(
                    bottom: 16,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.tempsRestant,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
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

          // Contenu de la fiche
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et sous-titre
                  Text(
                    widget.titre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.sousTitre,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prix comparatifs
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "${widget.prixGroupe} FCFA",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "${widget.prixPublic} FCFA",
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Économie : ${economie * _quantite} FCFA",
                          style: const TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // JAUGE D'AVANCEMENT DU GROUPE D'ACHAT
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Progression du groupe (${widget.quantiteActuelle}/${widget.quantiteObjectif} lots)",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "${(_pourcentage * 100).toInt()}%",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _pourcentage,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFEFE8E1),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: AppTheme.secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _reste > 0
                                    ? "Plus que $_reste commandes pour valider le tarif et déclencher le convoi !"
                                    : "Objectif atteint ! Expédition garantie.",
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SÉLECTEUR DE TAILLE / POINTURE
                  const Text(
                    "Choisir la pointure :",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _tailles.map((taille) {
                      final isSelected = taille == _tailleSelectionnee;
                      return GestureDetector(
                        onTap: () => setState(() => _tailleSelectionnee = taille),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : const Color(0xFFDED6CE),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              taille,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // SÉLECTEUR DE QUANTITÉ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Quantité à réserver :",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDED6CE)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _quantite > 1
                                  ? () => setState(() => _quantite--)
                                  : null,
                            ),
                            Text(
                              "$_quantite",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setState(() => _quantite++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // INFOS LOGISTIQUES ET SÉCURITÉ
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildInfoLigne(
                          icon: Icons.flight_takeoff,
                          titre: "Provenance & Fret",
                          valeur: widget.paysOrigine,
                        ),
                        const Divider(height: 20, color: Color(0xFFF1EAE2)),
                        _buildInfoLigne(
                          icon: Icons.local_shipping_outlined,
                          titre: "Acheminement assuré par",
                          valeur: widget.courtierNom,
                        ),
                        const Divider(height: 20, color: Color(0xFFF1EAE2)),
                        _buildInfoLigne(
                          icon: Icons.verified_user_outlined,
                          titre: "Garantie DoGo",
                          valeur: "Fonds protégés sous séquestre jusqu'au retrait",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Espace pour barre d'action fixe
                ],
              ),
            ),
          ),
        ],
      ),

      // Bouton flottant de retour en haut à gauche (Toujours visible et accessible)
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 14,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD4C5B9), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, color: AppTheme.textDark, size: 20),
                  SizedBox(width: 6),
                  Text(
                    "Retour",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),

      // Barre d'action fixe en bas
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total à payer :",
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                Text(
                  "${widget.prixGroupe * _quantite} FCFA",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RejoindreGroupeScreen(
                        titre: widget.titre,
                        quantite: _quantite,
                        taille: _tailleSelectionnee,
                        prixUnitaire: widget.prixGroupe,
                        courtierNom: widget.courtierNom,
                        imagePath: widget.imagePath,
                        paysOrigine: widget.paysOrigine,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Rejoindre le groupe",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLigne({
    required IconData icon,
    required String titre,
    required String valeur,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.tertiary.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                valeur,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
