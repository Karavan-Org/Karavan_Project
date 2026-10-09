import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/catalogue_api_service.dart';
import '../services/groupe_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/image_produit.dart';
import 'ajouter_produit_screen.dart';
import 'creer_groupe_grossiste_screen.dart';
import 'grossiste_drawer.dart';
import 'mes_groupes_grossiste_screen.dart';
import 'selection_produit_grossiste.dart';

/// Tableau de bord d'accueil du Grossiste : groupes en cours et catalogue actif.
/// Un produit du catalogue se sélectionne d'un appui ; le bouton (+) crée alors son groupe d'achat.
/// L'écran se recharge à chaque ajout de produit ou création de groupe (CatalogueApiService.revision).
class GrossisteDashboardScreen extends StatefulWidget {
  final bool showFab;

  const GrossisteDashboardScreen({
    super.key,
    this.showFab = true,
  });

  @override
  State<GrossisteDashboardScreen> createState() => _GrossisteDashboardScreenState();
}

class _GrossisteDashboardScreenState extends State<GrossisteDashboardScreen> {
  List<Map<String, dynamic>> _produits = [];
  List<GroupeResume> _groupes = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    CatalogueApiService.instance.revision.addListener(_charger);
    _charger();
  }

  @override
  void dispose() {
    CatalogueApiService.instance.revision.removeListener(_charger);
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        CatalogueApiService.instance.mesProduits(),
        GroupeApiService.instance.groupesDuGrossiste(),
      ]);
      if (!mounted) return;
      setState(() {
        _produits = resultats[0].map((p) => Map<String, dynamic>.from(p as Map)).toList();
        _groupes = resultats[1] as List<GroupeResume>;
        _chargement = false;
      });
      // La sélection suit les données fraîches (ou disparaît si le produit n'existe plus)
      final selection = SelectionProduitGrossiste.produit.value;
      if (selection != null) {
        final frais = _produits.where((p) => p['id'] == selection['id']);
        SelectionProduitGrossiste.produit.value = frais.isEmpty ? null : frais.first;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : '$e';
        _chargement = false;
      });
    }
  }

  void _ajouterProduit() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AjouterProduitScreen()));
  }

  void _creerGroupe(Map<String, dynamic>? produit) {
    SelectionProduitGrossiste.effacer();
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreerGroupeGrossisteScreen(produit: produit)));
  }

  void _voirGroupes({String filtre = "Tous"}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MesGroupesGrossisteScreen(filtreInitial: filtre)),
    ).then((_) => _charger());
  }

  int _groupesActifs(int produitId) => _groupes
      .where((g) => !['ANNULE', 'ECHOUE', 'TERMINE'].contains(g.statut))
      .where((g) => g.produitId == produitId)
      .length;

  @override
  Widget build(BuildContext context) {
    final aConfirmer = _groupes.where((g) => g.statut == 'EN_VALIDATION' && !g.disponibiliteValidee).length;
    final ouverts = _groupes.where((g) => g.statut == 'OUVERT').length;
    final reservees = _groupes
        .where((g) => g.statut == 'OUVERT' || g.statut == 'OBJECTIF_ATTEINT')
        .fold<int>(0, (t, g) => t + g.quantiteReservee + g.quantiteConfirmee);

    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const GrossisteDrawer(activeRoute: 'dashboard'),
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.textDark, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo_dogo.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(Icons.store, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Espace Grossiste",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textDark),
            tooltip: "Actualiser",
            onPressed: _charger,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: widget.showFab
          ? FloatingActionButton.extended(
              heroTag: 'fab-dashboard-grossiste',
              onPressed: _ajouterProduit,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Ajouter produit"),
            )
          : null,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            if (aConfirmer > 0) ...[
              _alerteConfirmation(aConfirmer),
              const SizedBox(height: 20),
            ],

            // --- CARTES STATISTIQUES ---
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _voirGroupes(filtre: "Ouverts"),
                    child: _buildKpiCard(
                      title: "Groupes ouverts",
                      value: "$ouverts",
                      subtext: "${_groupes.length} groupe${_groupes.length > 1 ? 's' : ''} au total",
                      icon: Icons.groups_rounded,
                      iconColor: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: "Pièces réservées",
                    value: "$reservees",
                    subtext: "sur vos groupes en cours",
                    icon: Icons.shopping_bag_rounded,
                    iconColor: AppTheme.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- EN-TÊTE SECTION MON CATALOGUE ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Mon Catalogue Actif",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textDark),
                ),
                TextButton(
                  onPressed: _ajouterProduit,
                  child: const Text("Ajouter", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (_produits.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  "Sélectionnez un produit puis appuyez sur + pour lancer son groupe d'achat.",
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
            ..._sectionCatalogue(),

            if (_groupes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Mes groupes d'achat",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textDark),
                  ),
                  TextButton(
                    onPressed: _voirGroupes,
                    child: const Text("Voir tout", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              for (final g in _groupes.take(3)) _ligneGroupe(g),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _sectionCatalogue() {
    if (_chargement && _produits.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ),
      ];
    }
    if (_erreur != null && _produits.isEmpty) {
      return [
        _carteVide(
          Icons.cloud_off_outlined,
          "Catalogue indisponible",
          _erreur!,
          action: TextButton(onPressed: _charger, child: const Text("Réessayer")),
        ),
      ];
    }
    if (_produits.isEmpty) {
      return [
        _carteVide(
          Icons.inventory_2_outlined,
          "Aucun article actif dans le catalogue",
          "Ajoutez un produit avec son prix de gros et son stock : vous pourrez ensuite lancer son groupe d'achat.",
        ),
      ];
    }
    return [
      ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: SelectionProduitGrossiste.produit,
        builder: (context, selection, _) => Column(
          children: [
            for (final p in _produits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _carteProduit(p, selection != null && selection['id'] == p['id']),
              ),
            if (selection != null)
              ElevatedButton.icon(
                onPressed: () => _creerGroupe(selection),
                icon: const Icon(Icons.group_add_rounded),
                label: Text("Créer le groupe « ${selection['nom'] ?? ''} »", overflow: TextOverflow.ellipsis),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _carteProduit(Map<String, dynamic> p, bool selectionne) {
    final stock = CatalogueApiService.stockTotal(p);
    final prix = p['prixGros'];
    final actifs = _groupesActifs((p['id'] as num).toInt());
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => SelectionProduitGrossiste.basculer(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectionne ? AppTheme.primary : const Color(0xFFEFE9E0),
              width: selectionne ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 60,
                  height: 60,
                  color: const Color(0xFFF7F2EB),
                  child: imageProduit(p['photoUrl']?.toString() ?? '', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['nom']?.toString() ?? 'Produit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        "Stock : $stock pcs",
                        if (prix is num) "${prix.round()} FCFA / pce",
                      ].join(" • "),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    if (actifs > 0)
                      Text(
                        "$actifs groupe${actifs > 1 ? 's' : ''} en cours",
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.success),
                      ),
                  ],
                ),
              ),
              Icon(
                selectionne ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selectionne ? AppTheme.primary : const Color(0xFFC7B8AA),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligneGroupe(GroupeResume g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: _voirGroupes,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const Icon(Icons.groups_rounded, color: AppTheme.primary),
          title: Text(
            g.titre.isNotEmpty ? g.titre : g.produitNom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          subtitle: Text(
            "${g.libelleStatut} • ${g.quantiteReservee + g.quantiteConfirmee}/${g.quantiteCible} pcs",
            style: const TextStyle(fontSize: 11.5),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }

  Widget _alerteConfirmation(int nombre) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E7), Color(0xFFFFF3D6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: AppTheme.secondary, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Disponibilité à confirmer (RG-18)",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF6D4C00)),
                ),
                const SizedBox(height: 2),
                Text(
                  "$nombre groupe${nombre > 1 ? 's' : ''} d'un courtier attend${nombre > 1 ? 'ent' : ''} la confirmation de votre stock.",
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A6516)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _voirGroupes(filtre: "À confirmer"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(60, 36),
            ),
            child: const Text("Voir", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _carteVide(IconData icone, String titre, String texte, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE9E0)),
      ),
      child: Column(
        children: [
          Icon(icone, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE8E0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 2),
          Text(subtext, style: const TextStyle(fontSize: 11.5, color: AppTheme.success, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
