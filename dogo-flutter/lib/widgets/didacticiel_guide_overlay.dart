import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../theme/app_theme.dart';
import '../services/session_storage_service.dart';
import '../services/auth_service.dart';

/// Didacticiel interactif guidé universel pour la première connexion de chaque type d'utilisateur
/// (Commerçant, Grossiste, Courtier — hors administrateur qui dispose du portail Angular).
/// Affiche une animation avec un doigt qui pointe précisément au-dessus du milieu de chaque bouton/onglet ciblé,
/// explique le but de l'application et guide l'utilisateur pas à pas avec validation par bouton "Suivant".
class DidacticielGuideOverlay extends StatefulWidget {
  final RoleActeur role;
  final VoidCallback onTermine;

  const DidacticielGuideOverlay({
    super.key,
    required this.role,
    required this.onTermine,
  });

  @override
  State<DidacticielGuideOverlay> createState() => _DidacticielGuideOverlayState();
}

class _DidacticielGuideOverlayState extends State<DidacticielGuideOverlay>
    with TickerProviderStateMixin {
  int _etapeCourante = 0;

  // Contrôleur pour l'animation d'oscillation du doigt qui montre (de haut en bas vers l'élément)
  late AnimationController _doigtController;
  late Animation<double> _doigtTranslation;

  // Contrôleur pour l'animation du halo pulsant autour de l'élément cible
  late AnimationController _pulsationController;
  late Animation<double> _pulsationScale;

  late final List<_EtapeGuideData> _etapes;

  @override
  void initState() {
    super.initState();
    _etapes = _genererEtapesPourRole(widget.role);

    // Animation d'oscillation verticale de la main au-dessus du tab visé
    _doigtController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _doigtTranslation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _doigtController, curve: Curves.easeInOut),
    );

    // Animation du halo pulsant autour du bouton visé
    _pulsationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulsationScale = Tween<double>(begin: 0.9, end: 1.3).animate(
      CurvedAnimation(parent: _pulsationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _doigtController.dispose();
    _pulsationController.dispose();
    super.dispose();
  }

  static List<_EtapeGuideData> _genererEtapesPourRole(RoleActeur role) {
    switch (role) {
      case RoleActeur.commercant:
        return const [
          _EtapeGuideData(
            titre: "Bienvenue sur DoGo Commerçant !",
            sousTitre: "LE BUT DE L'APPLICATION",
            description:
                "DoGo est la première plateforme d'achats groupés au Mali. En tant que Commerçant, cet écran d'accueil vous présente les meilleures opportunités d'achats groupés en direct des usines : tarifs dégressifs de gros et sécurité garantie sous séquestre bancaire.",
            cibleTab: 0, // Tab 0: Accueil
            icone: Icons.home_rounded,
          ),
          _EtapeGuideData(
            titre: "Explorer & Trouver des Produits",
            sousTitre: "FONCTIONNALITÉ 1 : LE CATALOGUE",
            description:
                "Parcourez des milliers d'articles classés par catégories (baskets, tissus, cosmétiques, quincaillerie...). Filtrez par provenance (Chine, Turquie, Dubaï, Local) et repérez les meilleures opportunités pour votre boutique.",
            cibleTab: 1, // Tab 1: Explorer
            icone: Icons.explore_rounded,
          ),
          _EtapeGuideData(
            titre: "Rejoindre ou Ouvrir un Groupe",
            sousTitre: "FONCTIONNALITÉ 2 : LE BOUTON (+)",
            description:
                "C'est le moteur de vos achats groupés ! Rejoignez un groupe avec un code d'invitation, initiez un nouvel achat groupé sur un article favori, suivez vos colis ou générez vos codes de retrait sécurisés.",
            cibleTab: -1, // -1 : FAB (+)
            icone: Icons.group_add_rounded,
          ),
          _EtapeGuideData(
            titre: "Suivi en Direct de vos Colis",
            sousTitre: "FONCTIONNALITÉ 3 : MES COMMANDES",
            description:
                "Suivez chaque étape en toute transparence : validation du groupe par les commerçants, préparation du stock par le grossiste, transit international et notification dès que vos cartons sont prêts au dépôt de Bamako.",
            cibleTab: 2, // Tab 2: Commandes
            icone: Icons.shopping_bag_rounded,
          ),
          _EtapeGuideData(
            titre: "Portefeuille & Séquestre Garanti",
            sousTitre: "FONCTIONNALITÉ 4 : PAIEMENTS PROTÉGÉS",
            description:
                "Votre argent est 100% protégé : chaque paiement reste bloqué sous séquestre bancaire certifié. Le grossiste n'est rémunéré que lorsque vous avez vérifié et retiré votre marchandise en main propre.",
            cibleTab: 3, // Tab 3: Profil & Portefeuille
            icone: Icons.account_balance_wallet_rounded,
          ),
        ];

      case RoleActeur.grossiste:
        return const [
          _EtapeGuideData(
            titre: "Bienvenue sur DoGo Vendeur !",
            sousTitre: "LE BUT DE L'APPLICATION",
            description:
                "DoGo est la première plateforme d'achats groupés au Mali et en Afrique de l'Ouest. En tant que Grossiste certifié, cet onglet Accueil vous donne une vue d'ensemble : chiffres clés, commandes du jour et alertes de stocks en direct.",
            cibleTab: 0, // Tab 0: Accueil
            icone: Icons.dashboard_rounded,
          ),
          _EtapeGuideData(
            titre: "Votre Catalogue & Variantes",
            sousTitre: "FONCTIONNALITÉ 1 : PRODUITS",
            description:
                "Ce bouton vous mène à votre inventaire. Renseignez ici vos articles (baskets, tissus, cosmétiques...) avec leurs déclinaisons (tailles, couleurs, pièces/carton) et vos prix de gros dégressifs.",
            cibleTab: 1, // Tab 1: Catalogue
            icone: Icons.inventory_2_rounded,
          ),
          _EtapeGuideData(
            titre: "Créer un Groupe d'Achat",
            sousTitre: "FONCTIONNALITÉ 2 : LE BOUTON (+)",
            description:
                "C'est le moteur de vos ventes ! Sélectionnez un produit et lancez une campagne d'achat groupé. Fixez le seuil de pièces à atteindre (ex : 500 paires) et la durée. Les commerçants réservent et paient leur part jusqu'à 100%.",
            cibleTab: -1, // -1 : FAB (+)
            icone: Icons.group_add_rounded,
          ),
          _EtapeGuideData(
            titre: "Validation & Expédition",
            sousTitre: "FONCTIONNALITÉ 3 : COMMANDES & STOCKS",
            description:
                "Dès qu'un groupe atteint 100%, vous confirmez la disponibilité de vos stocks. Le transitaire agréé DoGo prend alors en charge le lot et son acheminement sécurisé jusqu'aux commerçants de Bamako.",
            cibleTab: 2, // Tab 2: Ventes
            icone: Icons.local_shipping_rounded,
          ),
          _EtapeGuideData(
            titre: "Portefeuille & Séquestre Garanti",
            sousTitre: "FONCTIONNALITÉ 4 : PAIEMENTS & VIREMENTS",
            description:
                "Vos recettes sont protégées sous séquestre bancaire dès la commande. Dès que les commerçants réceptionnent leurs colis, vos fonds sont immédiatement débloqués et transférés sur votre compte bancaire (SWIFT / Local) ou Mobile Money.",
            cibleTab: 3, // Tab 3: Profil & Portefeuille
            icone: Icons.account_balance_wallet_rounded,
          ),
        ];

      case RoleActeur.courtier:
        return const [
          _EtapeGuideData(
            titre: "Bienvenue sur DoGo Courtier !",
            sousTitre: "LE BUT DE L'APPLICATION",
            description:
                "En tant que Courtier & Partenaire Transit, vous coordonnez les convois, regroupez les commandes d'import et facilitez la distribution aux commerçants tout en percevant des commissions transparentes.",
            cibleTab: 0, // Tab 0: Accueil
            icone: Icons.home_rounded,
          ),
          _EtapeGuideData(
            titre: "Gestion des Convois & Transit",
            sousTitre: "FONCTIONNALITÉ 1 : CONVOIS",
            description:
                "Suivez les conteneurs et lots en acheminement depuis les ports (Dakar, Abidjan, Conakry) jusqu'aux entrepôts de Bamako, et mettez à jour les jalons d'expédition en temps réel.",
            cibleTab: 1, // Tab 1: Convois
            icone: Icons.local_shipping_rounded,
          ),
          _EtapeGuideData(
            titre: "Actions Rapides & Retraits",
            sousTitre: "FONCTIONNALITÉ 2 : LE BOUTON (+)",
            description:
                "Déployez le menu pour créer un nouveau groupe d'achat, scanner le QR code de retrait d'un commerçant au dépôt ou valider une étape clé du transit.",
            cibleTab: -1, // -1 : FAB (+)
            icone: Icons.add_circle_rounded,
          ),
          _EtapeGuideData(
            titre: "Portefeuille & Commissions",
            sousTitre: "FONCTIONNALITÉ 3 : COMMISSIONS & GAINS",
            description:
                "Visualisez vos commissions acquises sur chaque conteneur et groupe d'achat finalisé. Demandez vos retraits directs vers votre compte bancaire ou compte Mobile Money.",
            cibleTab: 2, // Tab 2: Portefeuille
            icone: Icons.account_balance_wallet_rounded,
          ),
          _EtapeGuideData(
            titre: "Profil & Société de Transit",
            sousTitre: "FONCTIONNALITÉ 4 : COORDONNÉES & DÉPÔT",
            description:
                "Gérez les informations de votre entreprise de transit, votre licence agréée, l'adresse exacte de vos dépôts à Bamako et vos paramètres de sécurité.",
            cibleTab: 3, // Tab 3: Profil
            icone: Icons.business_center_rounded,
          ),
        ];
    }
  }

  void _marquerVuEtFermer() {
    final tel = AuthService.instance.profilActuel?.telephone ?? "defaut";
    SessionStorageService.instance.marquerGuideVu(widget.role.name, tel);
    widget.onTermine();
  }

  void _etapeSuivante() {
    if (_etapeCourante < _etapes.length - 1) {
      setState(() => _etapeCourante++);
    } else {
      _marquerVuEtFermer();
    }
  }

  void _etapePrecedente() {
    if (_etapeCourante > 0) {
      setState(() => _etapeCourante--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final etape = _etapes[_etapeCourante];
    final bool estDerniereEtape = _etapeCourante == _etapes.length - 1;
    final tailleEcran = MediaQuery.sizeOf(context);
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final double largeurEcran = tailleEcran.width;
    final largeurCarte = (largeurEcran - 44).clamp(0.0, 560.0).toDouble();

    // =========================================================================
    // CALCUL GÉOMÉTRIQUE EXACT CALQUÉ SUR LA BOTTOM BAR DE Dogo (Commercant/Grossiste/Courtier) :
    // - Hauteur de la barre = 64.0
    // - Row = [ Expanded(2 tabs), SizedBox(width: 52), Expanded(2 tabs) ]
    // - sideWidth = (largeurEcran - 52.0) / 2.0
    // - tabWidth = sideWidth / 2.0
    // =========================================================================
    const double barHeight = 64.0;
    const double largeurDoigt = 52.0;

    final double sideWidth = (largeurEcran - 52.0) / 2.0;
    final double tabWidth = sideWidth / 2.0;

    double tabCenterX;
    double tabTargetWidth;
    double tabTargetHeight;
    double tabTargetBottom;
    double tabTargetLeft;
    final bool isFab = etape.cibleTab == -1;

    if (isFab) {
      tabCenterX = largeurEcran / 2.0;
      tabTargetWidth = 58.0;
      tabTargetHeight = 58.0;
      tabTargetLeft = tabCenterX - 29.0;
      tabTargetBottom = safeAreaBottom + barHeight - 29.0 - 4.0;
    } else {
      tabTargetWidth = tabWidth;
      tabTargetHeight = barHeight;
      tabTargetBottom = safeAreaBottom;

      if (etape.cibleTab == 0) {
        tabTargetLeft = 0.0;
        tabCenterX = tabWidth * 0.5;
      } else if (etape.cibleTab == 1) {
        tabTargetLeft = tabWidth;
        tabCenterX = tabWidth * 1.5;
      } else if (etape.cibleTab == 2) {
        tabTargetLeft = sideWidth + 52.0;
        tabCenterX = tabTargetLeft + tabWidth * 0.5;
      } else {
        // Tab 3 : Profil & Portefeuille
        tabTargetLeft = sideWidth + 52.0 + tabWidth;
        tabCenterX = tabTargetLeft + tabWidth * 0.5;
      }
    }

    final double topCibleDepuisBas = tabTargetBottom + tabTargetHeight;
    final double handLeft = (tabCenterX - (largeurDoigt / 2.0)).clamp(0.0, largeurEcran - largeurDoigt);
    final double handBottomBase = topCibleDepuisBas + 6.0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Voile sombre pour focaliser l'attention
          GestureDetector(
            onTap: () {}, // Bloque les clics vers le fond
            child: Container(
              color: Colors.black.withValues(alpha: 0.68),
            ),
          ),

          // 2. Halo lumineux / projecteur autour de l'élément ciblé en bas
          Positioned(
            left: tabTargetLeft,
            bottom: tabTargetBottom,
            width: tabTargetWidth,
            height: tabTargetHeight,
            child: Center(
              child: GestureDetector(
                onTap: _etapeSuivante,
                child: _buildHaloCible(
                  isFab ? 58.0 : math.min(tabTargetWidth - 4.0, 78.0),
                  isFab ? 58.0 : 54.0,
                  isFab,
                ),
              ),
            ),
          ),

          // 3. Pointeur / Doigt animé qui montre l'élément visé, centré et JUSTE AU-DESSUS
          AnimatedBuilder(
            animation: _doigtController,
            builder: (context, child) {
              return Positioned(
                left: handLeft,
                bottom: handBottomBase + _doigtTranslation.value,
                child: GestureDetector(
                  onTap: _etapeSuivante,
                  child: _buildDoigtQuiMontre(),
                ),
              );
            },
          ),

          // 4. Bouton "Passer le guide" en haut à droite
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: TextButton.icon(
              onPressed: _marquerVuEtFermer,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              label: const Text(
                "Passer le guide",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // 5. Carte d'explication pédagogique avec bouton suivant
          Align(
            alignment: tailleEcran.height < 700
                ? const Alignment(0, -0.35)
                : const Alignment(0, -0.22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                width: largeurCarte,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: tailleEcran.height * 0.58,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 28,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFF0E5D8),
                          width: 1.8,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge d'étape
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "ÉTAPE ${_etapeCourante + 1} / ${_etapes.length}",
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  etape.sousTitre,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8C7E74),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Titre avec icône
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFEDD5)),
                                ),
                                child: Icon(etape.icone, color: const Color(0xFFD97706), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  etape.titre,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2C241E),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Explication détaillée
                          Text(
                            etape.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5A493B),
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Indicateurs de progression et boutons Suivant / Précédent
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Points indicateurs
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  _etapes.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _etapeCourante == index ? 20 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _etapeCourante == index
                                          ? AppTheme.primary
                                          : const Color(0xFFE5DDD5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Boutons d'action
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_etapeCourante > 0) ...[
                                    TextButton(
                                      onPressed: _etapePrecedente,
                                      style: TextButton.styleFrom(
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      ),
                                      child: const Text(
                                        "Précédent",
                                        style: TextStyle(
                                          color: Color(0xFF8C7E74),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],

                                  ElevatedButton(
                                    onPressed: _etapeSuivante,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          estDerniereEtape ? "Terminer" : "Suivant",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          estDerniereEtape
                                              ? Icons.rocket_launch_rounded
                                              : Icons.arrow_forward_rounded,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Halo / projecteur lumineux pulsant qui encadre l'onglet en bas
  Widget _buildHaloCible(double width, double height, bool isFab) {
    return AnimatedBuilder(
      animation: _pulsationController,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: isFab ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isFab ? null : BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF59E0B),
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(
                  alpha: (0.30 + 0.35 * (1.0 - _pulsationScale.value / 1.3)).clamp(0.0, 1.0),
                ),
                blurRadius: 10 * _pulsationScale.value,
                spreadRadius: 2 * _pulsationScale.value,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construit le widget animé du doigt qui montre le bouton vers le bas
  Widget _buildDoigtQuiMontre() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Badge circulaire contenant la main
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55F59E0B),
                blurRadius: 16,
                spreadRadius: 2,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Transform.rotate(
              angle: math.pi, // Tourne l'icône touch_app pour que l'index pointe directement vers le bas 👇
              child: const Icon(
                Icons.touch_app_rounded,
                color: Color(0xFFD97706),
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Petite flèche / chevron doré pointant vers le bas pour marquer le point de contact
        const Icon(
          Icons.arrow_drop_down_rounded,
          color: Color(0xFFF59E0B),
          size: 22,
        ),
      ],
    );
  }
}

class _EtapeGuideData {
  final String titre;
  final String sousTitre;
  final String description;
  final int cibleTab; // 0: Accueil, 1: Catalogue/Explorer/Convois, -1: FAB (+), 2: Commandes/Ventes/Portefeuille, 3: Profil
  final IconData icone;

  const _EtapeGuideData({
    required this.titre,
    required this.sousTitre,
    required this.description,
    required this.cibleTab,
    required this.icone,
  });
}
