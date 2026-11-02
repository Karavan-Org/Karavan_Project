import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import 'selecteur_piece.dart';

/// Écran « Notifier l'administration » conforme à la maquette Figma officielle
/// Permet au grossiste de notifier l'administrateur de l'avancement d'un convoi ou colis,
/// et de signaler immédiatement un incident ou blocage logistique avec justificatif.
class NotifierAdministrationScreen extends StatefulWidget {
  final GroupeResume? groupe;
  final Map<String, dynamic>? convoi;
  final String? etapeInitiale;
  final bool modeIncident;

  const NotifierAdministrationScreen({
    super.key,
    this.groupe,
    this.convoi,
    this.etapeInitiale,
    this.modeIncident = false,
  });

  @override
  State<NotifierAdministrationScreen> createState() => _NotifierAdministrationScreenState();
}

class _EtapeOption {
  final String titre;
  final IconData icone;
  final bool estIncident;

  const _EtapeOption({
    required this.titre,
    required this.icone,
    this.estIncident = false,
  });
}

class _NotifierAdministrationScreenState extends State<NotifierAdministrationScreen> {
  static const List<_EtapeOption> _etapesDisponibles = [
    _EtapeOption(
      titre: "Arrivée au Port de Dakar (Transit)",
      icone: Icons.anchor_rounded,
    ),
    _EtapeOption(
      titre: "Marchandise commandée au fournisseur",
      icone: Icons.inventory_2_outlined,
    ),
    _EtapeOption(
      titre: "Colis expédiés / Pris en charge par le transitaire",
      icone: Icons.local_shipping_outlined,
    ),
    _EtapeOption(
      titre: "En transit maritime (En mer)",
      icone: Icons.directions_boat_filled_rounded,
    ),
    _EtapeOption(
      titre: "En transit aérien (En vol)",
      icone: Icons.flight_takeoff_rounded,
    ),
    _EtapeOption(
      titre: "Arrivée en douane frontière",
      icone: Icons.gavel_rounded,
    ),
    _EtapeOption(
      titre: "Marchandise dédouanée",
      icone: Icons.check_circle_outline_rounded,
    ),
    _EtapeOption(
      titre: "En convoi terrestre vers Bamako",
      icone: Icons.fire_truck_outlined,
    ),
    _EtapeOption(
      titre: "Arrivé au dépôt Karavan (Bamako)",
      icone: Icons.storefront_rounded,
    ),
    // Incidents et blocages
    _EtapeOption(
      titre: "Incident : Blocage en douane",
      icone: Icons.warning_amber_rounded,
      estIncident: true,
    ),
    _EtapeOption(
      titre: "Incident : Retard transporteur / avarie",
      icone: Icons.report_problem_outlined,
      estIncident: true,
    ),
    _EtapeOption(
      titre: "Incident : Colis endommagé ou manquant",
      icone: Icons.broken_image_outlined,
      estIncident: true,
    ),
    _EtapeOption(
      titre: "Autre problème logistique urgent",
      icone: Icons.error_outline_rounded,
      estIncident: true,
    ),
  ];

  late _EtapeOption _etapeSelectionnee;
  final TextEditingController _detailsController = TextEditingController();

  List<GroupeResume> _groupesDisponibles = [];
  GroupeResume? _groupeActuel;
  Map<String, dynamic>? _convoiActuel;

  FichierChoisi? _fichierJustificatif;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _groupeActuel = widget.groupe;
    _convoiActuel = widget.convoi;

    // Étape par défaut
    if (widget.modeIncident) {
      _etapeSelectionnee = _etapesDisponibles.firstWhere(
        (e) => e.estIncident,
        orElse: () => _etapesDisponibles.first,
      );
      _detailsController.text = "";
    } else if (widget.etapeInitiale != null) {
      _etapeSelectionnee = _etapesDisponibles.firstWhere(
        (e) => e.titre.toLowerCase().contains(widget.etapeInitiale!.toLowerCase()),
        orElse: () => _etapesDisponibles.first,
      );
      _detailsController.text =
          "Le conteneur est arrivé au Port de Dakar. Débarquement en cours, acheminement terrestre prévu vers Bamako sous 48h à 72h.";
    } else {
      _etapeSelectionnee = _etapesDisponibles.first;
      _detailsController.text =
          "Le conteneur est arrivé au Port de Dakar. Débarquement en cours, acheminement terrestre prévu vers Bamako sous 48h à 72h.";
    }

    _initialiserGroupes();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _initialiserGroupes() async {
    try {
      final groupes = await GroupeApiService.instance.groupesDuGrossiste();
      final actifs = groupes.where((g) => !['BROUILLON', 'ANNULE', 'ECHOUE'].contains(g.statut)).toList();
      if (!mounted) return;
      setState(() {
        _groupesDisponibles = actifs;
        _groupeActuel ??= actifs.isNotEmpty ? actifs.first : null;
      });
    } catch (_) {
      // Ignorer l'erreur réseau silencieusement
    }
  }

  String _referenceAffichee() {
    if (_convoiActuel != null) {
      final code = _convoiActuel!['code'] ?? '#TR-BKO-${_convoiActuel!['id'] ?? 88}';
      final trajet = _convoiActuel!['trajet'] ?? 'Convoi Istanbul / Guangzhou';
      return '$code ($trajet)';
    }
    if (_groupeActuel != null) {
      final ref = '#TR-BKO-${_groupeActuel!.id.toString().padLeft(2, '0')}';
      final titre = _groupeActuel!.titre.isNotEmpty ? _groupeActuel!.titre : _groupeActuel!.produitNom;
      return '$ref ($titre)';
    }
    return "#TR-BKO-88 (Convoi Istanbul / Guangzhou)";
  }

  void _choisirGroupe() {
    if (_groupesDisponibles.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              "Sélectionnez le groupe ou convoi",
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.couleurTexte(context),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _groupesDisponibles.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final g = _groupesDisponibles[i];
                  final isSelected = _groupeActuel?.id == g.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    title: Text(
                      "#TR-BKO-${g.id.toString().padLeft(2, '0')} • ${g.produitNom}",
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF7B4026) : AppTheme.couleurTexte(context),
                      ),
                    ),
                    subtitle: Text("${g.quantiteProgression} / ${g.quantiteCible} pcs • ${g.libelleStatut}"),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF7B4026)) : null,
                    onTap: () {
                      setState(() => _groupeActuel = g);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _ouvrirSelectionEtape() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Choisir l'étape ou signaler un incident",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.couleurTexte(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Sélectionnez le jalon actuel ou un incident à notifier d'urgence à l'administrateur :",
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.couleurTexteAttenue(context),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: _etapesDisponibles.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final e = _etapesDisponibles[i];
                  final isSelected = _etapeSelectionnee.titre == e.titre;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: e.estIncident
                            ? const Color(0xFFFEE2E2)
                            : (isSelected ? const Color(0xFFFDF4EE) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        e.icone,
                        color: e.estIncident ? const Color(0xFFDC2626) : const Color(0xFF7B4026),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      e.titre,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: e.estIncident
                            ? const Color(0xFFDC2626)
                            : (isSelected ? const Color(0xFF7B4026) : AppTheme.couleurTexte(context)),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFF7B4026), size: 20)
                        : null,
                    onTap: () {
                      setState(() {
                        _etapeSelectionnee = e;
                        if (e.estIncident && _detailsController.text.contains("Débarquement en cours")) {
                          _detailsController.text = "";
                        }
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joindrePiece() async {
    final piece = await choisirPiece(
      context,
      titre: "Bordereau, reçu douane ou photo colis",
    );
    if (piece != null) {
      setState(() => _fichierJustificatif = piece);
    }
  }

  Future<void> _soumettre() async {
    final details = _detailsController.text.trim();
    final groupeId = _groupeActuel?.id ?? widget.groupe?.id;

    if (groupeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner un groupe ou convoi."),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (_etapeSelectionnee.estIncident && details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez préciser la nature de l'incident pour l'administrateur."),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _envoiEnCours = true);

    try {
      if (_etapeSelectionnee.estIncident) {
        // Envoi direct de l'incident à l'administration
        await GroupeApiService.instance.signalerIncident(
          groupeId,
          motif: _etapeSelectionnee.titre,
          detail: details.isNotEmpty ? details : null,
          pieceJointeUrl: _fichierJustificatif?.nom,
        );
      } else {
        // Envoi de l'étape logistique
        await GroupeApiService.instance.signalerEtape(
          groupeId,
          etape: _etapeSelectionnee.titre,
          commentaire: details.isNotEmpty ? details : null,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _etapeSelectionnee.estIncident
                ? "Incident transmis d'urgence aux administrateurs Karavan."
                : "Statut logistique transmis : l'administration et les commerçants sont informés.",
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoiEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : 'Erreur d\'envoi : $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estIncident = _etapeSelectionnee.estIncident;

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.couleurTexte(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Notifier l'administration",
                style: TextStyle(
                  fontFamily: AppTheme.policeTitre,
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexte(context),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("●", style: TextStyle(color: Color(0xFFD97706), fontSize: 9)),
                  SizedBox(width: 5),
                  Text(
                    "SUIVI CONVOI",
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sous-titre
              Text(
                "Mise à jour du statut logistique",
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.couleurTexteAttenue(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // 1. CHAMP : Référence du groupe ou du convoi
              Text(
                "Référence du groupe ou du convoi",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.couleurTexte(context),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _choisirGroupe,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _referenceAffichee(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.couleurTexte(context),
                          ),
                        ),
                      ),
                      if (_groupesDisponibles.length > 1)
                        Icon(Icons.unfold_more_rounded, color: Colors.grey.shade500, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. CHAMP : Étape logistique actuelle
              Text(
                "Étape logistique actuelle",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.couleurTexte(context),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _ouvrirSelectionEtape,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: estIncident ? const Color(0xFFDC2626) : const Color(0xFF7B4026),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _etapeSelectionnee.icone,
                        color: estIncident ? const Color(0xFFDC2626) : const Color(0xFF7B4026),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _etapeSelectionnee.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: estIncident ? const Color(0xFFDC2626) : AppTheme.couleurTexte(context),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: estIncident ? const Color(0xFFDC2626) : const Color(0xFF7B4026),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. CHAMP : Détails d'avancement pour l'administrateur
              Text(
                estIncident ? "Description du problème pour l'administrateur" : "Détails d'avancement pour l'administrateur",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: estIncident ? const Color(0xFFDC2626) : AppTheme.couleurTexte(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: estIncident ? const Color(0xFFFCA5A5) : Colors.grey.shade300,
                  ),
                ),
                child: TextField(
                  controller: _detailsController,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppTheme.couleurTexte(context),
                  ),
                  decoration: InputDecoration(
                    hintText: estIncident
                        ? "Décrivez ici la nature exacte du problème, les raisons du retard/blocage et les actions entreprises..."
                        : "Le conteneur est arrivé au Port de Dakar. Débarquement en cours, acheminement terrestre prévu vers Bamako sous 48h à 72h.",
                    hintStyle: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.grey.shade400,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. CHAMP : Pièce justificative
              Text(
                "Pièce justificative (Bordereau, photo colis, reçu douane)",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.couleurTexte(context),
                ),
              ),
              const SizedBox(height: 8),

              // Conteneur en pointillés
              CustomPaint(
                painter: _DottedBorderPainter(
                  color: Colors.grey.shade300,
                  strokeWidth: 1.5,
                  dashPattern: const [6, 4],
                  radius: 16,
                ),
                child: InkWell(
                  onTap: _joindrePiece,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                    child: _fichierJustificatif == null
                        ? Column(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5EBE1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Color(0xFF78350F),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Joindre le document ou photo du reçu",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Format PDF, JPG ou PNG (max 10 Mo)",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5EBE1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.description_rounded,
                                  color: Color(0xFF78350F),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fichierJustificatif!.nom,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      "${(_fichierJustificatif!.octets.lengthInBytes / 1024).toStringAsFixed(1)} Ko • Fichier prêt à être envoyé",
                                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                                onPressed: () => setState(() => _fichierJustificatif = null),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 5. BANDEAU DE STATUT EN TEMPS RÉEL (Vert ou Alerte)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: estIncident ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: estIncident ? const Color(0xFFF87171) : const Color(0xFF86EFAC),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      estIncident ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: estIncident ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            estIncident ? "Alerte prioritaire transmise à l'administrateur" : "Mise à jour du suivi en temps réel",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: estIncident ? const Color(0xFF991B1B) : const Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            estIncident
                                ? "L'équipe logistique Karavan interviendra pour débloquer la situation."
                                : "Les commerçants du groupe recevront le statut mis à jour.",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: estIncident ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 6. BOUTONS : Notifier l'administration & Annuler
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _envoiEnCours ? null : _soumettre,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B4026),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _envoiEnCours
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          estIncident ? "Transmettre l'alerte à l'administration" : "Notifier l'administration",
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Annuler",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.couleurTexteAttenue(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter pour le tracé en pointillés arrondis
class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final List<double> dashPattern;
  final double radius;

  const _DottedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashPattern,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      int patternIndex = 0;
      while (distance < metric.length) {
        final length = dashPattern[patternIndex % dashPattern.length];
        if (patternIndex % 2 == 0) {
          final extractPath = metric.extractPath(distance, distance + length);
          canvas.drawPath(extractPath, paint);
        }
        distance += length;
        patternIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      radius != oldDelegate.radius;
}
