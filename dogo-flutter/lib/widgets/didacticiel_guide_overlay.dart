import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../theme/app_theme.dart';
import '../services/session_storage_service.dart';
import '../services/auth_service.dart';

/// Emplacements ciblables par le didacticiel interactif
enum EmplacementCible {
  tabAccueil,
  tabCatalogue,
  tabCommandes,
  tabProfil,
  fabCentral,
  tableauDeBordKpi,
  catalogueActifSection,
  enTeteProfilEtTheme,
  commercantRechercheFiltres,
  courtierKpiTransit,
}

/// Clés des éléments réels mis en lumière par le didacticiel (cartes du tableau de bord, en-têtes).
///
/// Chaque espace en possède une instance (créée par son écran principal et transmise par
/// [PorteeCiblesDidacticiel]) : une clé globale ne peut être portée que par un seul widget, et deux
/// espaces peuvent coexister un instant (transition, route empilée). Des clés `static` partagées
/// provoqueraient alors l'erreur « Duplicate GlobalKeys ».
class CiblesDidacticiel {
  final GlobalKey fabCentral = GlobalKey(debugLabel: 'didacticiel.fabCentral');
  final GlobalKey grossisteKpi = GlobalKey(debugLabel: 'didacticiel.grossisteKpi');
  final GlobalKey grossisteCatalogueEnTete = GlobalKey(debugLabel: 'didacticiel.grossisteCatalogueEnTete');
  final GlobalKey grossisteBarreApp = GlobalKey(debugLabel: 'didacticiel.grossisteBarreApp');

  /// Cibles de l'espace englobant, ou null hors d'un espace : l'étape garde alors sa position par défaut.
  static CiblesDidacticiel? de(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PorteeCiblesDidacticiel>()?.cibles;
}

/// Transmet les [CiblesDidacticiel] d'un espace à ses écrans et à son didacticiel.
class PorteeCiblesDidacticiel extends InheritedWidget {
  final CiblesDidacticiel cibles;

  const PorteeCiblesDidacticiel({super.key, required this.cibles, required super.child});

  @override
  bool updateShouldNotify(PorteeCiblesDidacticiel oldWidget) => !identical(oldWidget.cibles, cibles);
}

/// Didacticiel interactif guidé universel pour la première connexion de chaque type d'utilisateur
/// (Commerçant, Grossiste, Courtier).
/// Met en lumière les éléments réels de l'écran (cartes du tableau de bord, catalogue, FAB +,
/// onglets de navigation, en-tête profil/thème) avec un projecteur lumineux et un doigt animé qui pointe
/// précisément vers l'élément ciblé (vers le haut ou vers le bas selon sa position).
class DidacticielGuideOverlay extends StatefulWidget {
  final RoleActeur role;
  final VoidCallback onTermine;

  const DidacticielGuideOverlay({
    super.key,
    required this.role,
    required this.onTermine,
  });

  @override
  State<DidacticielGuideOverlay> createState() =>
      _DidacticielGuideOverlayState();
}

class _DidacticielGuideOverlayState extends State<DidacticielGuideOverlay>
    with TickerProviderStateMixin {
  int _etapeCourante = 0;

  // Contrôleur pour l'animation d'oscillation du doigt qui montre l'élément visé
  late AnimationController _doigtController;
  late Animation<double> _doigtTranslation;

  // Contrôleur pour l'animation du halo pulsant autour de l'élément cible
  late AnimationController _pulsationController;
  late Animation<double> _pulsationScale;

  late List<_EtapeGuideData> _etapes;

  @override
  void initState() {
    super.initState();
    _etapes = _genererEtapesPourRole(widget.role, CiblesDidacticiel.de(context));

    // Animation d'oscillation de la main au-dessus ou en-dessous de l'élément visé
    _doigtController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _doigtTranslation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _doigtController, curve: Curves.easeInOut),
    );

    // Animation du halo pulsant autour de la cible
    _pulsationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulsationScale = Tween<double>(begin: 0.95, end: 1.25).animate(
      CurvedAnimation(parent: _pulsationController, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _etapes = _genererEtapesPourRole(widget.role, CiblesDidacticiel.de(context));
  }

  @override
  void dispose() {
    _doigtController.dispose();
    _pulsationController.dispose();
    super.dispose();
  }

  static List<_EtapeGuideData> _genererEtapesPourRole(RoleActeur role, CiblesDidacticiel? cibles) {
    switch (role) {
      case RoleActeur.grossiste:
        return [
          _EtapeGuideData(
            titre: "Tableau de Bord & Chiffres Clés",
            sousTitre: "TABLEAU DE BORD : STATISTIQUES",
            description:
                "Bienvenue sur votre espace Vendeur ! Ce tableau de bord affiche vos indicateurs en direct : vos groupes d'achat ouverts, les pièces déjà réservées par les commerçants et vos alertes de validation.",
            emplacement: EmplacementCible.tableauDeBordKpi,
            cleGlobale: cibles?.grossisteKpi,
            icone: Icons.dashboard_rounded,
          ),
          _EtapeGuideData(
            titre: "Mon Catalogue Actif & Ajout",
            sousTitre: "VOS PRODUITS & STOCKS",
            description:
                "Consultez ici la liste de vos articles en vente et leurs prix de gros. Touchez « Ajouter » pour enregistrer un nouvel article (tailles, couleurs, pièces/carton), ou appuyez sur un produit pour préparer son achat groupé.",
            emplacement: EmplacementCible.catalogueActifSection,
            cleGlobale: cibles?.grossisteCatalogueEnTete,
            icone: Icons.inventory_2_rounded,
          ),
          _EtapeGuideData(
            titre: "Créer un Groupe d'Achat",
            sousTitre: "FONCTIONNALITÉ 2 : LE BOUTON (+)",
            description:
                "C'est le moteur de vos ventes ! Touchez (+) pour lancer une campagne d'achat groupé. Fixez le seuil de pièces à atteindre (ex : 500 paires) et la durée : les commerçants réservent et paient leur part jusqu'à 100%.",
            emplacement: EmplacementCible.fabCentral,
            cleGlobale: cibles?.fabCentral,
            isCircle: true,
            icone: Icons.group_add_rounded,
          ),
          const _EtapeGuideData(
            titre: "Validation & Expédition",
            sousTitre: "FONCTIONNALITÉ 3 : COMMANDES & STOCKS",
            description:
                "Dès qu'un groupe atteint 100%, vous confirmez la disponibilité de vos stocks. Le transitaire agréé Karavan prend alors en charge le lot et son acheminement sécurisé jusqu'aux commerçants de Bamako.",
            emplacement: EmplacementCible.tabCommandes,
            icone: Icons.local_shipping_rounded,
          ),
          const _EtapeGuideData(
            titre: "Portefeuille & Séquestre Garanti",
            sousTitre: "FONCTIONNALITÉ 4 : PAIEMENTS & VIREMENTS",
            description:
                "Vos recettes sont protégées sous séquestre bancaire dès la commande. Dès que les commerçants réceptionnent leurs colis, vos fonds sont immédiatement débloqués et transférés vers votre compte bancaire ou Mobile Money.",
            emplacement: EmplacementCible.tabProfil,
            icone: Icons.account_balance_wallet_rounded,
          ),
          _EtapeGuideData(
            titre: "Menu, Paramètres & Mode Sombre",
            sousTitre: "VOTRE EN-TÊTE PERSONNEL",
            description:
                "Gérez les informations de votre boutique, basculez en mode sombre ou clair en un clic, et ouvrez le menu latéral pour l'assistance en direct et vos paramètres de compte.",
            emplacement: EmplacementCible.enTeteProfilEtTheme,
            cleGlobale: cibles?.grossisteBarreApp,
            icone: Icons.tune_rounded,
          ),
        ];

      case RoleActeur.commercant:
        return [
          const _EtapeGuideData(
            titre: "Bienvenue sur Karavan Commerçant !",
            sousTitre: "LE BUT DE L'APPLICATION",
            description:
                "Karavan est la première plateforme d'achats groupés au Mali. En tant que Commerçant, cet écran d'accueil vous présente les meilleures opportunités d'achats groupés en direct des usines : tarifs dégressifs de gros et sécurité garantie sous séquestre bancaire.",
            emplacement: EmplacementCible.tabAccueil,
            icone: Icons.home_rounded,
          ),
          const _EtapeGuideData(
            titre: "Explorer & Trouver des Produits",
            sousTitre: "FONCTIONNALITÉ 1 : LE CATALOGUE",
            description:
                "Parcourez des milliers d'articles classés par catégories (baskets, tissus, cosmétiques, quincaillerie...). Filtrez par provenance (Chine, Turquie, Dubaï, Local) et repérez les meilleures opportunités pour votre boutique.",
            emplacement: EmplacementCible.tabCatalogue,
            icone: Icons.explore_rounded,
          ),
          _EtapeGuideData(
            titre: "Rejoindre ou Ouvrir un Groupe",
            sousTitre: "FONCTIONNALITÉ 2 : LE BOUTON (+)",
            description:
                "C'est le moteur de vos achats groupés ! Rejoignez un groupe avec un code d'invitation, initiez un nouvel achat groupé sur un article favori, suivez vos colis ou générez vos codes de retrait sécurisés.",
            emplacement: EmplacementCible.fabCentral,
            cleGlobale: cibles?.fabCentral,
            isCircle: true,
            icone: Icons.group_add_rounded,
          ),
          const _EtapeGuideData(
            titre: "Suivi en Direct de vos Colis",
            sousTitre: "FONCTIONNALITÉ 3 : MES COMMANDES",
            description:
                "Suivez chaque étape en toute transparence : validation du groupe par les commerçants, préparation du stock par le grossiste, transit international et notification dès que vos cartons sont prêts au dépôt de Bamako.",
            emplacement: EmplacementCible.tabCommandes,
            icone: Icons.shopping_bag_rounded,
          ),
          const _EtapeGuideData(
            titre: "Portefeuille & Séquestre Garanti",
            sousTitre: "FONCTIONNALITÉ 4 : PAIEMENTS PROTÉGÉS",
            description:
                "Votre argent est 100% protégé : chaque paiement reste bloqué sous séquestre bancaire certifié. Le grossiste n'est rémunéré que lorsque vous avez vérifié et retiré votre marchandise en main propre.",
            emplacement: EmplacementCible.tabProfil,
            icone: Icons.account_balance_wallet_rounded,
          ),
        ];

      case RoleActeur.courtier:
        return [
          const _EtapeGuideData(
            titre: "Bienvenue sur Karavan Courtier !",
            sousTitre: "LE BUT DE L'APPLICATION",
            description:
                "En tant que Courtier & Partenaire Transit, vous coordonnez les convois, regroupez les commandes d'import et facilitez la distribution aux commerçants tout en percevant des commissions transparentes.",
            emplacement: EmplacementCible.tabAccueil,
            icone: Icons.home_rounded,
          ),
          const _EtapeGuideData(
            titre: "Gestion des Convois & Transit",
            sousTitre: "FONCTIONNALITÉ 1 : CONVOIS",
            description:
                "Suivez les conteneurs et lots en acheminement depuis les ports (Dakar, Abidjan, Conakry) jusqu'aux entrepôts de Bamako, et mettez à jour les jalons d'expédition en temps réel.",
            emplacement: EmplacementCible.tabCatalogue,
            icone: Icons.local_shipping_rounded,
          ),
          _EtapeGuideData(
            titre: "Actions Rapides & Retraits",
            sousTitre: "FONCTIONNALITÉ 2 : LE BOUTON (+)",
            description:
                "Déployez le menu pour créer un nouveau groupe d'achat, scanner le QR code de retrait d'un commerçant au dépôt ou valider une étape clé du transit.",
            emplacement: EmplacementCible.fabCentral,
            cleGlobale: cibles?.fabCentral,
            isCircle: true,
            icone: Icons.add_circle_rounded,
          ),
          const _EtapeGuideData(
            titre: "Portefeuille & Commissions",
            sousTitre: "FONCTIONNALITÉ 3 : COMMISSIONS & GAINS",
            description:
                "Visualisez vos commissions acquises sur chaque conteneur et groupe d'achat finalisé. Demandez vos retraits directs vers votre compte bancaire ou compte Mobile Money.",
            emplacement: EmplacementCible.tabCommandes,
            icone: Icons.account_balance_wallet_rounded,
          ),
          const _EtapeGuideData(
            titre: "Profil & Société de Transit",
            sousTitre: "FONCTIONNALITÉ 4 : COORDONNÉES & DÉPÔT",
            description:
                "Gérez les informations de votre entreprise de transit, votre licence agréée, l'adresse exacte de vos dépôts à Bamako et vos paramètres de sécurité.",
            emplacement: EmplacementCible.tabProfil,
            icone: Icons.business_center_rounded,
          ),
        ];
    }
  }

  void _marquerVuEtFermer() {
    final role = widget.role.name;
    if (mounted) widget.onTermine();
    unawaited(_enregistrerGuideVu(role));
  }

  Future<void> _enregistrerGuideVu(String role) async {
    var tel = AuthService.instance.profilActuel?.telephone;
    var uid = AuthService.instance.profilActuel?.id;
    if (tel == null || tel.isEmpty || uid == null) {
      final profil = await SessionStorageService.instance.lireProfil();
      tel ??= profil?.telephone;
      uid ??= profil?.id;
    }
    tel ??= "defaut";
    await SessionStorageService.instance.marquerGuideVu(role, tel, utilisateurId: uid);
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

  /// Résout le rectangle géométrique de la cible à mettre en valeur
  Rect _calculerRectCible(
      _EtapeGuideData etape, Size screenSize, EdgeInsets padding) {
    // 1. Tenter la mesure dynamique via GlobalKey si présente et attachée
    if (etape.cleGlobale?.currentContext != null) {
      final renderBox =
          etape.cleGlobale!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize && renderBox.attached) {
        final overlayBox = context.findRenderObject() as RenderBox?;
        final Offset globalPos = renderBox.localToGlobal(Offset.zero);
        final Offset pos = (overlayBox != null && overlayBox.hasSize && overlayBox.attached)
            ? overlayBox.globalToLocal(globalPos)
            : globalPos;
        final size = renderBox.size;
        if (size.width > 10 && size.height > 10) {
          if (etape.isCircle) {
            final globalCenter = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
            final center = (overlayBox != null && overlayBox.hasSize && overlayBox.attached)
                ? overlayBox.globalToLocal(globalCenter)
                : (pos + Offset(size.width / 2.0, size.height / 2.0));
            final radius = (math.max(size.width, size.height) / 2.0) + 5.0;
            return Rect.fromCircle(center: center, radius: radius);
          }
          return (pos & size).inflate(6.0);
        }
      }
    }

    // 2. Fallback géométrique exact et réactif
    final double safeBottom = padding.bottom;
    final double safeTop = padding.top;
    final double largeur = screenSize.width;
    final double hauteur = screenSize.height;

    const double barHeight = 64.0;
    final double sideWidth = (largeur - 52.0) / 2.0;
    final double tabWidth = sideWidth / 2.0;

    switch (etape.emplacement) {
      case EmplacementCible.tabAccueil:
        return Rect.fromLTWH(
            0, hauteur - safeBottom - barHeight, tabWidth, barHeight);

      case EmplacementCible.tabCatalogue:
        return Rect.fromLTWH(
            tabWidth, hauteur - safeBottom - barHeight, tabWidth, barHeight);

      case EmplacementCible.tabCommandes:
        return Rect.fromLTWH(sideWidth + 52.0, hauteur - safeBottom - barHeight,
            tabWidth, barHeight);

      case EmplacementCible.tabProfil:
        return Rect.fromLTWH(sideWidth + 52.0 + tabWidth,
            hauteur - safeBottom - barHeight, tabWidth, barHeight);

      case EmplacementCible.fabCentral:
        final cx = largeur / 2.0;
        // Le FAB central est amarré à cheval au-dessus de la barre de navigation
        final cy = hauteur - safeBottom - barHeight + 4.0;
        return Rect.fromCircle(center: Offset(cx, cy), radius: 34.0);

      case EmplacementCible.tableauDeBordKpi:
        final w = math.min(largeur - 32.0, 560.0);
        final l = (largeur - w) / 2.0;
        final t = safeTop + 56.0 + 16.0;
        return Rect.fromLTWH(l, t, w, 148.0);

      case EmplacementCible.catalogueActifSection:
        final w = math.min(largeur - 32.0, 560.0);
        final l = (largeur - w) / 2.0;
        final t = safeTop + 56.0 + 16.0 + 148.0 + 20.0;
        return Rect.fromLTWH(l, t, w, 68.0);

      case EmplacementCible.enTeteProfilEtTheme:
        return Rect.fromLTWH(10.0, safeTop + 4.0, largeur - 20.0, 54.0);

      case EmplacementCible.commercantRechercheFiltres:
        final w = math.min(largeur - 32.0, 560.0);
        final l = (largeur - w) / 2.0;
        final t = safeTop + 68.0;
        return Rect.fromLTWH(l, t, w, 82.0);

      case EmplacementCible.courtierKpiTransit:
        final w = math.min(largeur - 32.0, 560.0);
        final l = (largeur - w) / 2.0;
        final t = safeTop + 56.0 + 16.0;
        return Rect.fromLTWH(l, t, w, 140.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final etape = _etapes[_etapeCourante];
    final bool estDerniereEtape = _etapeCourante == _etapes.length - 1;
    final tailleEcran = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final double largeurEcran = tailleEcran.width;
    final double hauteurEcran = tailleEcran.height;
    final double largeurCarte =
        (largeurEcran - 40).clamp(0.0, 560.0).toDouble();

    final targetRect = _calculerRectCible(etape, tailleEcran, padding);

    // Détermine si la cible est située dans la moitié inférieure de l'écran
    final bool estEnBas = targetRect.center.dy > (hauteurEcran * 0.52);

    // Positionnement géométrique du doigt qui montre (largeur 52, hauteur bulle 50 + chevron 22 = 72)
    const double largeurDoigt = 52.0;
    const double hauteurDoigt = 72.0;
    final double handLeft = (targetRect.center.dx - (largeurDoigt / 2.0))
        .clamp(12.0, largeurEcran - largeurDoigt - 12.0);

    // Positionnement dynamique de la carte explicative pour ne jamais chevaucher la cible ni le doigt
    Alignment carteAlignment;
    if (estEnBas) {
      // Cible en bas (ex : onglets, FAB) -> carte au-dessus
      carteAlignment = hauteurEcran < 700
          ? const Alignment(0, -0.40)
          : const Alignment(0, -0.28);
    } else {
      // Cible en haut ou milieu (ex : KPI, catalogue, en-tête) -> carte en-dessous
      if (targetRect.bottom > hauteurEcran * 0.35) {
        carteAlignment = const Alignment(0, 0.65);
      } else {
        carteAlignment = const Alignment(0, 0.42);
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Voile sombre découpé (cutout) : l'élément ciblé reste 100% visible et lumineux
          GestureDetector(
            onTap: () {}, // Bloque les interactions hors guide
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              size: tailleEcran,
              painter: _VoileDecoupePainter(
                cibleRect: targetRect,
                isCircle: etape.isCircle,
              ),
            ),
          ),

          // 2. Halo lumineux pulsant avec bordure dorée autour de la cible
          Positioned(
            left: targetRect.left,
            top: targetRect.top,
            width: targetRect.width,
            height: targetRect.height,
            child: GestureDetector(
              onTap: _etapeSuivante,
              behavior: HitTestBehavior.opaque,
              child: _buildHaloCible(
                  targetRect.width, targetRect.height, etape.isCircle),
            ),
          ),

          // 3. Doigt animé qui montre l'élément visé (vers le bas 👇 ou vers le haut 👆)
          AnimatedBuilder(
            animation: _doigtController,
            builder: (context, child) {
              double topPos;
              if (estEnBas) {
                // Doigt au-dessus de la cible, pointant vers le bas avec marge nette
                topPos = targetRect.top -
                    hauteurDoigt -
                    10.0 -
                    _doigtTranslation.value;
              } else {
                // Doigt en-dessous de la cible, pointant vers le haut avec marge nette
                topPos = targetRect.bottom + 10.0 + _doigtTranslation.value;
              }

              return Positioned(
                left: handLeft,
                top: topPos,
                child: GestureDetector(
                  onTap: _etapeSuivante,
                  child: _buildDoigtQuiMontre(pointeVersLeBas: estEnBas),
                ),
              );
            },
          ),

          // 4. Bouton discret "Passer le guide" en haut à droite
          Positioned(
            top: padding.top + 14,
            right: 18,
            child: TextButton.icon(
              onPressed: _marquerVuEtFermer,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                ),
              ),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 16),
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

          // 5. Carte explicative claire avec boutons Précédent / Suivant
          Align(
            alignment: carteAlignment,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: largeurCarte,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: hauteurEcran * 0.52,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                        border: Border.all(
                          color: AppTheme.surfaceDouce,
                          width: 1.8,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge d'étape
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.12),
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
                                    color: AppTheme.textMuted,
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
                                  color: AppTheme.ocreClair,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.ocreClair),
                                ),
                                child: Icon(etape.icone,
                                    color: AppTheme.ocreProfond, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  etape.titre,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.terre,
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
                              color: AppTheme.terreDouce,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Indicateurs de progression et boutons Suivant / Précédent
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Points indicateurs
                              Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      _etapes.length,
                                      (index) => AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        width: _etapeCourante == index ? 20 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _etapeCourante == index
                                              ? AppTheme.primary
                                              : AppTheme.bordureForte,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
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
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                      ),
                                      child: const Text(
                                        "Précédent",
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
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
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          estDerniereEtape
                                              ? "Terminer"
                                              : "Suivant",
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

  /// Halo / projecteur lumineux pulsant qui encadre l'élément ciblé
  Widget _buildHaloCible(double width, double height, bool isCircle) {
    return AnimatedBuilder(
      animation: _pulsationController,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.ocre,
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ocre.withValues(
                  alpha: (0.30 + 0.35 * (1.0 - _pulsationScale.value / 1.25))
                      .clamp(0.0, 1.0),
                ),
                blurRadius: 12 * _pulsationScale.value,
                spreadRadius: 2.5 * _pulsationScale.value,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construit le doigt animé qui pointe vers l'élément visé
  /// ([pointeVersLeBas] = true quand la cible est en bas, false quand elle est en haut)
  Widget _buildDoigtQuiMontre({required bool pointeVersLeBas}) {
    final chevron = Icon(
      pointeVersLeBas
          ? Icons.arrow_drop_down_rounded
          : Icons.arrow_drop_up_rounded,
      color: AppTheme.ocreProfond,
      size: 22,
    );

    final bulle = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.ocre, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55E6A823),
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
          angle: pointeVersLeBas
              ? math.pi
              : 0, // Pointe vers le bas 👇 ou vers le haut 👆
          child: const Icon(
            Icons.touch_app_rounded,
            color: AppTheme.ocreProfond,
            size: 26,
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!pointeVersLeBas) chevron,
        bulle,
        if (pointeVersLeBas) chevron,
      ],
    );
  }
}

/// Peintre du masque sombre avec découpe nette au niveau de l'élément cible
class _VoileDecoupePainter extends CustomPainter {
  final Rect cibleRect;
  final bool isCircle;

  _VoileDecoupePainter({
    required this.cibleRect,
    required this.isCircle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pleinEcran = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (cibleRect.isEmpty || cibleRect.width <= 0 || cibleRect.height <= 0) {
      canvas.drawPath(
          pleinEcran, Paint()..color = Colors.black.withValues(alpha: 0.68));
      return;
    }

    final trou = Path();
    if (isCircle) {
      trou.addOval(cibleRect);
    } else {
      trou.addRRect(
          RRect.fromRectAndRadius(cibleRect, const Radius.circular(16)));
    }

    final masque = Path.combine(PathOperation.difference, pleinEcran, trou);
    canvas.drawPath(
        masque, Paint()..color = Colors.black.withValues(alpha: 0.68));
  }

  @override
  bool shouldRepaint(covariant _VoileDecoupePainter oldDelegate) =>
      oldDelegate.cibleRect != cibleRect || oldDelegate.isCircle != isCircle;
}

class _EtapeGuideData {
  final String titre;
  final String sousTitre;
  final String description;
  final EmplacementCible emplacement;
  final GlobalKey? cleGlobale;
  final bool isCircle;
  final IconData icone;

  const _EtapeGuideData({
    required this.titre,
    required this.sousTitre,
    required this.description,
    required this.emplacement,
    this.cleGlobale,
    this.isCircle = false,
    required this.icone,
  });
}
