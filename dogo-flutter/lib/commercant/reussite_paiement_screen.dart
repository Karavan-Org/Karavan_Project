import '../widgets/image_produit.dart';
import '../widgets/drapeau_pays_widget.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groupe_api_service.dart';
import '../widgets/app_popups.dart';
import '../widgets/tab_navigation_scope.dart';

/// Écran de confirmation de Paiement Réussi conforme au design Figma (# reussite paiement)
/// avec jauge dynamique et réactive liée au groupe d'achat (progression réelle animée).
class ReussitePaiementScreen extends StatefulWidget {
  /// Identifiant du groupe d'achat pour actualisation dynamique
  final dynamic groupeId;

  /// Participation payée : c'est elle qu'annule le bouton « Annuler la commande » (RG-31).
  final int participationId;
  final String titreProduit;
  final String paysOrigine;
  final int prixUnitaire;
  final int quantite;
  final int montantTotal;
  final String moyenPaiement;
  final String dateHeure;
  final String imagePath;
  final int piecesActuelles;
  final int piecesObjectif;

  const ReussitePaiementScreen({
    super.key,
    this.groupeId,
    required this.participationId,
    required this.prixUnitaire,
    required this.quantite,
    required this.montantTotal,
    required this.moyenPaiement,
    required this.dateHeure,
    this.titreProduit = "",
    this.paysOrigine = "",
    this.imagePath = "",
    this.piecesActuelles = 0,
    this.piecesObjectif = 0,
  });

  @override
  State<ReussitePaiementScreen> createState() => _ReussitePaiementScreenState();
}

class _ReussitePaiementScreenState extends State<ReussitePaiementScreen>
    with SingleTickerProviderStateMixin {
  late int _piecesActuelles;
  late int _piecesObjectif;
  late int _piecesDepart;
  late String _titre;
  late String _pays;
  late String _image;
  late AnimationController _animController;
  late Animation<double> _animation;
  bool _actualisationEnCours = false;

  bool get _estEnTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _piecesActuelles = widget.piecesActuelles;
    _piecesObjectif = widget.piecesObjectif;
    _titre = widget.titreProduit;
    _pays = widget.paysOrigine;
    _image = widget.imagePath;

    // Progression initiale de départ : niveau du groupe avant la commande qui vient d'être payée
    if (_piecesActuelles > 0 && widget.quantite > 0) {
      _piecesDepart = (_piecesActuelles - widget.quantite).clamp(0, _piecesObjectif > 0 ? _piecesObjectif : _piecesActuelles);
    } else {
      _piecesDepart = 0;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    if (_estEnTest) {
      _animController.value = 1.0;
    } else {
      _animController.forward();
    }

    _chargerProgressionReelle();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Récupère la progression la plus fraîche depuis le serveur pour garantir l'exactitude
  Future<void> _chargerProgressionReelle() async {
    final gid = widget.groupeId;
    if (gid == null || gid.toString().isEmpty) return;

    if (mounted) setState(() => _actualisationEnCours = true);
    try {
      final groupe = await GroupeApiService.instance.detail(gid);
      if (!mounted) return;
      setState(() {
        _piecesActuelles = groupe.quantiteActuelle;
        _piecesObjectif = groupe.quantiteObjectif;
        if (_titre.isEmpty && groupe.titre.isNotEmpty) _titre = groupe.titre;
        if (_pays.isEmpty && groupe.paysOrigine.isNotEmpty) _pays = groupe.paysOrigine;
        if (_image.isEmpty && groupe.imagePath.isNotEmpty) _image = groupe.imagePath;

        if (_piecesDepart > _piecesActuelles) {
          _piecesDepart = (_piecesActuelles - widget.quantite).clamp(0, _piecesObjectif > 0 ? _piecesObjectif : 0);
        }
      });

      if (!_estEnTest && !_animController.isAnimating && _animController.value < 1.0) {
        _animController.forward(from: 0.0);
      }
    } catch (_) {
      // Les valeurs passées au constructeur restent appliquées en repli
    } finally {
      if (mounted) setState(() => _actualisationEnCours = false);
    }
  }

  String _formatMontant(int montant) {
    final str = montant.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return "${str.replaceAllMapped(reg, (Match m) => '${m[1]} ')} FCFA";
  }

  void _confirmerAnnulation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Annuler la commande ?",
          style: TextStyle(fontFamily: AppTheme.policeTitre, 
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.couleurTexte(context),
          ),
        ),
        content: Text(
          "Votre participation sera annulée et le remboursement de votre paiement lancé, sans frais d'annulation.",
          style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Garder ma commande", style: TextStyle(color: AppTheme.couleurTexteAttenue(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await GroupeApiService.instance.annulerParticipation(widget.participationId);
              } catch (e) {
                if (context.mounted) await AppPopups.traiterErreurOuConflit(context, e);
                return;
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Participation annulée. Votre remboursement est en cours de traitement."),
                  backgroundColor: AppTheme.danger,
                ),
              );
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
              TabNavigationScope.switchToTab(context, 0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Confirmer l'annulation"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fondEcran = isDark ? AppTheme.darkBackground : AppTheme.creme;
    final Color couleurTexte = isDark ? Colors.white : AppTheme.terre;
    final Color couleurCarte = isDark ? AppTheme.darkSurface : Colors.white;
    final Color couleurBordure = isDark ? AppTheme.darkBordure : AppTheme.bordure;

    final bool progressionConnue = _piecesObjectif > 0;

    void quitterVersEspace(int tabIndex) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      TabNavigationScope.switchToTab(context, tabIndex);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        quitterVersEspace(0);
      },
      child: Scaffold(
        backgroundColor: fondEcran,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: couleurTexte, size: 22),
            onPressed: () => quitterVersEspace(0),
          ),
        ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. GRAND BADGE CIRCULAIRE VERT AVEC CONFETTIS FIGMA
            SizedBox(
              height: 94,
              width: 94,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(94, 94),
                    painter: _ConfettiPainter(),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppTheme.olive,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. TITRE & SOUS-TITRE PRINCIPAL
            Text(
              "Paiement effectué\navec succès !",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppTheme.policeTitre, 
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: couleurTexte,
                height: 1.25,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Votre participation au groupe a bien été prise en compte.\nLes fonds sont sécurisés sur votre compte AchatGroup jusqu'à la validation du groupe.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white70 : AppTheme.textMuted,
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. ENCART DE SÉCURITÉ ("Votre paiement est sécurisé")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkOliveSurface : AppTheme.oliveClair,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkOliveSurface : AppTheme.oliveBordure,
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppTheme.olive,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Votre paiement est sécurisé",
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkOlive : AppTheme.oliveProfond,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Nous ne transférons les fonds au courtier que lorsque le groupe atteint 100%.",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppTheme.darkOlive : AppTheme.oliveProfond,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. MINI-CARTE PRODUIT FIGMA AVEC JAUGE ANIMÉE ET DYNAMIQUE
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final double t = _animation.value;
                final int piecesAffichees = progressionConnue
                    ? (_piecesDepart + ((_piecesActuelles - _piecesDepart) * t)).round().clamp(0, _piecesObjectif)
                    : _piecesActuelles;
                final double pct = progressionConnue
                    ? (piecesAffichees / _piecesObjectif).clamp(0.0, 1.0)
                    : 0.0;
                final int pctInt = (pct * 100).toInt();
                final bool estObjectifAtteint = progressionConnue && piecesAffichees >= _piecesObjectif;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: couleurCarte,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: couleurBordure, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : const Color(0x0A2C241E),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Vignette du produit
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 82,
                          height: 82,
                          color: isDark ? AppTheme.darkSurfaceDouce : AppTheme.surfaceDouce,
                          padding: const EdgeInsets.all(6),
                          child: imageProduit(
                            _image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined,
                              size: 38,
                              color: AppTheme.bissap,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Informations produit & Jauge d'avancement dynamique
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _titre.isNotEmpty ? _titre : widget.titreProduit,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: couleurTexte,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: estObjectifAtteint
                                        ? (isDark ? AppTheme.darkOliveSurface : AppTheme.oliveClair)
                                        : (isDark ? AppTheme.darkOcreSurface : AppTheme.ocreClair),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (estObjectifAtteint) ...[
                                        const Icon(Icons.check_circle, size: 11, color: AppTheme.oliveProfond),
                                        const SizedBox(width: 3),
                                      ],
                                      Text(
                                        estObjectifAtteint ? "Objectif atteint 🎉" : "Groupe en cours",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: estObjectifAtteint ? AppTheme.oliveProfond : AppTheme.ocreProfond,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            DrapeauBadge(
                              pays: _pays.isNotEmpty ? _pays : widget.paysOrigine,
                              compact: true,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_formatMontant(widget.prixUnitaire)} / unité",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: couleurTexte,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Barre de progression dynamique animée
                            if (progressionConnue) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: isDark ? AppTheme.darkBordure : AppTheme.bordure,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    estObjectifAtteint ? AppTheme.olive : AppTheme.ocre,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "$piecesAffichees / $_piecesObjectif pièces",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.white70 : AppTheme.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    "$pctInt%",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: estObjectifAtteint ? AppTheme.oliveProfond : AppTheme.ocreProfond,
                                    ),
                                  ),
                                ],
                              ),
                              if (estObjectifAtteint)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 12, color: AppTheme.oliveProfond),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "Objectif 100% atteint ! Expédition garantie 🚀",
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark ? AppTheme.darkOlive : AppTheme.oliveProfond,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_piecesObjectif - piecesAffichees > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.bolt_rounded, size: 12, color: AppTheme.ocreProfond),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          "Plus que ${_piecesObjectif - piecesAffichees} pièces pour clôturer le groupe",
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark ? AppTheme.ocreProfond : AppTheme.bissap,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ] else if (_actualisationEnCours) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 5,
                                  backgroundColor: isDark ? AppTheme.darkBordure : AppTheme.bordure,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.ocre),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Actualisation de la jauge...",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white60 : AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 22),

            // 5. SECTION DÉTAILS DE VOTRE PAIEMENT
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Détails de votre paiement",
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: couleurTexte,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildDetailRow(
              context: context,
              icon: Icons.inventory_2_outlined,
              label: "Quantité commandée",
              value: "${widget.quantite} pièces",
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              context: context,
              icon: Icons.sell_outlined,
              label: "Prix unitaire garanti",
              value: _formatMontant(widget.prixUnitaire),
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              context: context,
              icon: Icons.receipt_long_outlined,
              label: "Montant total payé",
              value: _formatMontant(widget.montantTotal),
              isBoldValue: true,
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              context: context,
              icon: Icons.smartphone_outlined,
              label: "Moyen de paiement",
              value: widget.moyenPaiement,
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              context: context,
              icon: Icons.access_time_outlined,
              label: "Date et heure",
              value: widget.dateHeure,
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              context: context,
              icon: Icons.confirmation_number_outlined,
              label: "Participation",
              value: "#${widget.participationId}",
            ),

            const SizedBox(height: 32),

            // 6. BOUTON D'ACTION PRINCIPAL : "Voir mes commandes →"
            ElevatedButton(
              onPressed: () => quitterVersEspace(2),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bissap,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Voir mes commandes",
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 7. LIEN ROUGE : "Annuler Commande"
            TextButton(
              onPressed: () => _confirmerAnnulation(context),
              child: const Text(
                "Annuler Commande",
                style: TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    bool isBoldValue = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.bissap),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isBoldValue ? FontWeight.w800 : FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.terre,
            ),
          ),
        ],
      ),
    );
  }
}

/// Peintre personnalisé des confettis/particules autour du rond de succès
class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final particles = [
      _Dot(cx - 36, cy - 22, 2.5, AppTheme.olive),
      _Dot(cx + 38, cy - 18, 3.0, AppTheme.ocre),
      _Dot(cx + 26, cy - 36, 2.2, AppTheme.bissap),
      _Dot(cx - 24, cy - 38, 2.0, AppTheme.olive),
      _Dot(cx - 40, cy + 18, 2.8, AppTheme.ocre),
      _Dot(cx + 36, cy + 24, 2.4, AppTheme.olive),
    ];

    for (final p in particles) {
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dot {
  final double x;
  final double y;
  final double radius;
  final Color color;
  _Dot(this.x, this.y, this.radius, this.color);
}
