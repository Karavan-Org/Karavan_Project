import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/image_produit.dart';
import '../widgets/partage_groupe.dart';
import '../grossiste/suivi_colis_grossiste_screen.dart';
import '../grossiste/notifier_administration_screen.dart';

/// Écran « Détail du groupe » fidèle à la maquette Figma officielle
class DetailGroupeScreen extends StatefulWidget {
  final GroupeResume groupe;

  const DetailGroupeScreen({super.key, required this.groupe});

  @override
  State<DetailGroupeScreen> createState() => _DetailGroupeScreenState();
}

class _DetailGroupeScreenState extends State<DetailGroupeScreen> {
  late GroupeResume _groupe;
  List<Map<String, dynamic>> _commandes = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _groupe = widget.groupe;
    _chargerCommandes();
  }

  Future<void> _chargerCommandes() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final data = await GroupeApiService.instance.commandesDuGroupe(_groupe.id);
      if (!mounted) return;
      setState(() {
        _commandes = data;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : '$e';
        _chargement = false;
      });
    }
  }

  String _formatReference(int id) => '#DG-${id.toString().padLeft(4, '0')}';

  String _formatDureeRelative(DateTime? date) {
    if (date == null) return "Récemment";
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) {
      return "Créé il y a ${(diff.inDays / 30).floor()} mois";
    } else if (diff.inDays >= 1) {
      return "Créé il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}";
    } else if (diff.inHours >= 1) {
      return "Créé il y a ${diff.inHours}h";
    } else {
      return "Créé aujourd'hui";
    }
  }

  String _initiales(String nom) {
    final clean = nom.replaceAll(RegExp(r'^(Ets|Boutique|Société|Magasin)\s+', caseSensitive: false), '').trim();
    final parts = clean.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      final brute = nom.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      if (brute.length >= 2) return "${brute[0][0]}${brute[1][0]}".toUpperCase();
      if (brute.isNotEmpty && brute[0].length >= 2) return brute[0].substring(0, 2).toUpperCase();
      return "CL";
    }
    if (parts.length >= 2) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    if (parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts[0].toUpperCase();
  }

  String _formaterPrix(num montant) {
    final str = montant.round().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]} ');
  }

  void _ouvrirChoixNotification() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Notifier",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: AppTheme.policeTitre,
                color: AppTheme.couleurTexte(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Sélectionnez le type de notification à transmettre :",
              style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
            ),
            const SizedBox(height: 18),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B4026).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7B4026), size: 24),
              ),
              title: const Text(
                "Notifier l'administration",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              subtitle: const Text(
                "Mettre à jour l'étape du convoi, joindre un reçu ou signaler un incident/blocage",
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotifierAdministrationScreen(groupe: _groupe),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE59324).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFFE59324), size: 24),
              ),
              title: Text(
                "Informer les acheteurs (${_commandes.length})",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              subtitle: const Text(
                "Diffuser un message d'information à tous les commerçants inscrits",
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                _ouvrirDialogueNotification();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

  void _ouvrirDialogueNotification() {
    final controller = TextEditingController();
    bool envoi = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final insetsBottom = MediaQuery.of(context).viewInsets.bottom;
          final systemBottom = MediaQuery.of(context).padding.bottom;
          final bottomPadding = insetsBottom > 0 ? insetsBottom + 16 : systemBottom + 24;

          return SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                bottomPadding,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Notifier les acheteurs",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.couleurTexte(context),
                          ),
                        ),
                        Text(
                          "Groupe ${_formatReference(_groupe.id)} • ${_commandes.length} acheteur(s)",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.couleurTexteAttenue(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Message de notification en direct :",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.couleurTexte(context),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Ex : Les colis sont prêts pour acheminement, expédition en cours...",
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: AppTheme.couleurSurfaceDouce(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE59324), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _modeleMessage("Stock prêt à être expédié", controller),
                  _modeleMessage("Colis en cours de préparation", controller),
                  _modeleMessage("Arrivée prévue cette semaine", controller),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: envoi
                      ? null
                      : () async {
                          final msg = controller.text.trim();
                          if (msg.isEmpty) return;
                          setModalState(() => envoi = true);
                          try {
                            await GroupeApiService.instance.notifierGroupe(_groupe.id, msg);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Notification transmise à tous les acheteurs du groupe"),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          } catch (e) {
                            setModalState(() => envoi = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e is ApiException ? e.messageComplet : 'Erreur : $e'),
                                backgroundColor: AppTheme.danger,
                              ),
                            );
                          }
                        },
                  icon: envoi
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Envoyer la notification",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE59324),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
),
);
}

  Widget _modeleMessage(String titre, TextEditingController controller) {
    return InkWell(
      onTap: () => controller.text = titre,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          titre,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF374151), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    final piecesAffichees = _groupe.quantiteProgression;
    final quantiteCible = _groupe.quantiteCible > 0 ? _groupe.quantiteCible : 1;
    final montantTotalGroupe = piecesAffichees * _groupe.prixUnitaire;
    final totalSequestre = montantTotalGroupe;

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).cardColor,
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.couleurTexte(context),
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Détail du groupe",
              style: TextStyle(
                fontFamily: AppTheme.policeTitre,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.couleurTexte(context),
              ),
            ),
            Text(
              "Réf: ${_formatReference(_groupe.id)} • ${_formatDureeRelative(_groupe.dateOuverture)}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.couleurTexteAttenue(context),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor,
                border: Border.all(color: Colors.grey.shade300, width: 0.8),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: AppTheme.couleurTexte(context),
                  size: 20,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'partager') {
                    afficherPartageGroupe(context, _groupe);
                  } else if (val == 'actualiser') {
                    _chargerCommandes();
                  } else if (val == 'notifier_admin') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotifierAdministrationScreen(groupe: _groupe),
                      ),
                    );
                  } else if (val == 'suivi' && _groupe.acheminementAuGrossiste) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SuiviColisGrossisteScreen(),
                      ),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'actualiser',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 10),
                        Text("Actualiser"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'notifier_admin',
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 18),
                        SizedBox(width: 10),
                        Text("Notifier l'administration (Colis/Incident)"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'partager',
                    child: Row(
                      children: [
                        Icon(Icons.share_rounded, size: 18),
                        SizedBox(width: 10),
                        Text("Partager le groupe"),
                      ],
                    ),
                  ),
                  if (_groupe.acheminementAuGrossiste)
                    const PopupMenuItem(
                      value: 'suivi',
                      child: Row(
                        children: [
                          Icon(Icons.local_shipping_rounded, size: 18),
                          SizedBox(width: 10),
                          Text("Suivi colis & Acheminement"),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE59324),
          onRefresh: _chargerCommandes,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. CARTE PRINCIPALE DU GROUPE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rangée Produit + Titre + Badge %
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 60,
                              height: 60,
                              color: AppTheme.couleurSurfaceDouce(context),
                              child: imageProduit(_groupe.photoUrl ?? '', fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _groupe.titre.isNotEmpty ? _groupe.titre : _groupe.produitNom,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                    color: AppTheme.couleurTexte(context),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "${_groupe.produitNom} • ${_formaterPrix(_groupe.prixUnitaire)} FCFA / unité",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.couleurTexteAttenue(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge pourcentage
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "●",
                                  style: TextStyle(color: Color(0xFFD97706), fontSize: 10),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "${_groupe.pourcentageProgression}%",
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Volume réservé
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Volume réservé",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.couleurTexteAttenue(context),
                            ),
                          ),
                          Text(
                            "$piecesAffichees/$quantiteCible pcs",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Barre de progression
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _groupe.ratioProgression,
                          minHeight: 10,
                          backgroundColor: estSombre ? Colors.white12 : const Color(0xFFF3F4F6),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE59324)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Sous-ligne : Statut Fermée/Ouvert + Montant total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _groupe.aAtteint100 || const ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE', 'TERMINE'].contains(_groupe.statut)
                                  ? "Fermée"
                                  : (_groupe.statut == 'OUVERT' ? "Ouverte" : _groupe.libelleStatut),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _groupe.aAtteint100 || const ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE', 'TERMINE'].contains(_groupe.statut)
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "${_formaterPrix(montantTotalGroupe)} FCFA",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Bandeau Stock réservé
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF6EE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                "●",
                                style: TextStyle(color: Color(0xFF92400E), fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$piecesAffichees pcs de votre stock sont actuellement réservées pour ce groupe.",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. CARTE FONDS SOUS SÉQUESTRE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF16A34A),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total des fonds sous séquestre Karavan",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.couleurTexteAttenue(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "${_formaterPrix(totalSequestre)} FCFA",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.couleurTexte(context),
                                  ),
                                ),
                                const Text(
                                  "(Garantis)",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 3. SECTION COMMANDES ENREGISTRÉES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Commandes enregistrées (${_commandes.length} acheteurs)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.couleurTexte(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Liste des acheteurs / commandes
                if (_chargement)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Color(0xFFE59324)),
                    ),
                  )
                else if (_erreur != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Impossible de charger les acheteurs : $_erreur",
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.danger),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_commandes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          "Aucune commande enregistrée pour l'instant",
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.couleurTexteAttenue(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Les réservations et paiements des commerçants s'afficheront ici en temps réel.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _commandes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = _commandes[i];
                      final nom = (c['commercantNom']?.toString().isNotEmpty ?? false)
                          ? c['commercantNom'].toString()
                          : "Acheteur #${c['id'] ?? (i + 1)}";
                      final quantite = c['quantite'] is num
                          ? (c['quantite'] as num).toInt()
                          : int.tryParse(c['quantite']?.toString() ?? '0') ?? 0;
                      final montant = quantite * _groupe.prixUnitaire;
                      final ville = ((c['pointRetrait'] as Map?)?['quartier']?.toString() ??
                                      (c['pointRetrait'] as Map?)?['adresse']?.toString()) ??
                          "Bamako";

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Cercle avec initiales
                            Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5EBE1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _initiales(nom),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Nom + Localisation / Quantité
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nom,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.couleurTexte(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "$ville • $quantite pcs",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.couleurTexteAttenue(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Montant
                            Text(
                              "${_formaterPrix(montant)} F",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _ouvrirChoixNotification,
                icon: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 20),
                label: const Text(
                  "Notifier",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE59324),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
