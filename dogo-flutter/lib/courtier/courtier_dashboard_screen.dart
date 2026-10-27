import 'dart:async';
import '../widgets/bouton_bascule_theme.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/convoi_api_service.dart';
import '../services/groupe_api_service.dart';
import '../services/notification_api_service.dart';
import '../services/portefeuille_api_service.dart';
import '../services/visibilite_ecran.dart';
import '../utils/format.dart';
import '../widgets/zone_portefeuille_neumorphic.dart';
import 'gestion_convoi_screen.dart';
import 'creer_groupe_courtier_screen.dart';
import 'notifications_courtier_screen.dart';
import 'portefeuille_courtier_screen.dart';
import 'scanner_retrait_screen.dart';
import '../widgets/image_produit.dart';

/// Tableau de bord d'accueil du Courtier, alimenté en direct : solde et séquestre de son portefeuille,
/// ses groupes, ses convois en cours et ses notifications non lues.
class CourtierDashboardScreen extends StatefulWidget {
  final bool showBottomNav;

  const CourtierDashboardScreen({
    super.key,
    this.showBottomNav = true,
  });

  @override
  State<CourtierDashboardScreen> createState() => _CourtierDashboardScreenState();
}

class _CourtierDashboardScreenState extends State<CourtierDashboardScreen> {
  int _bottomIndex = 0;

  PortefeuilleInfo? _portefeuille;
  List<Convoi> _convois = [];
  List<GroupeResume> _groupes = [];
  int _nonLues = 0;
  bool _charge = false;
  Timer? _actualisation;

  @override
  void initState() {
    super.initState();
    _charger();
    _actualisation = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && ecranVisible(context)) _charger();
    });
  }

  @override
  void dispose() {
    _actualisation?.cancel();
    super.dispose();
  }

  /// Chaque bloc se charge indépendamment : une source en panne n'empêche pas les autres de s'afficher
  Future<void> _charger() async {
    final resultats = await Future.wait<Object?>([
      PortefeuilleApiService.instance.voirPortefeuille().catchError((_) => null),
      ConvoiApiService.instance.lister().then<Object?>((c) => c).catchError((_) => null),
      GroupeApiService.instance.mesGroupesCourtier().then<Object?>((g) => g).catchError((_) => null),
      NotificationApiService.instance.nombreNonLues().then<Object?>((n) => n),
    ]);
    if (!mounted) return;
    setState(() {
      _portefeuille = resultats[0] as PortefeuilleInfo? ?? _portefeuille;
      if (resultats[1] != null) _convois = resultats[1] as List<Convoi>;
      if (resultats[2] != null) _groupes = resultats[2] as List<GroupeResume>;
      _nonLues = resultats[3] as int;
      _charge = true;
    });
  }

  Future<void> _ouvrir(Widget ecran) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));
    _charger(); // retour : soldes, convois et notifications peuvent avoir changé
  }

  @override
  Widget build(BuildContext context) {
    final convoisEnCours = _convois.where((c) => !c.estArrive).toList();
    final groupesParId = {for (final g in _groupes) g.id: g};
    final groupesOuverts = _groupes.where((g) => g.statut == 'OUVERT').length;

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: AppTheme.couleurCarte(context),
        elevation: 0,
        centerTitle: false,
        title: ValueListenableBuilder<UtilisateurProfil?>(
          valueListenable: AuthService.instance.profilNotifier,
          builder: (context, user, _) {
            final nom = user?.nomComplet.isNotEmpty == true ? user!.nomComplet : "";
            final structure = user?.structure;
            final bool aPhoto = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;

            return Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppTheme.rose,
                  backgroundImage: aPhoto ? imageReseauDimensionnee(context, user.photoUrl!, 34) : null,
                  child: !aPhoto ? const Icon(Icons.person, color: AppTheme.terre, size: 20) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.couleurTexte(context))),
                      if (structure != null && structure.isNotEmpty)
                        Text(structure, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: AppTheme.couleurSucces(context), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          const BoutonBasculeTheme(compact: true),
          IconButton(
            tooltip: "Notifications",
            icon: Badge.count(
              count: _nonLues,
              isLabelVisible: _nonLues > 0,
              child: Icon(Icons.notifications_none_rounded, color: AppTheme.couleurTexte(context)),
            ),
            onPressed: () => _ouvrir(const NotificationsCourtierScreen()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: _bottomIndex,
              onTap: (index) {
                setState(() => _bottomIndex = index);
                if (index == 1) {
                  _ouvrir(const GestionConvoiScreen());
                } else if (index == 2) {
                  _ouvrir(const CreerGroupeCourtierScreen());
                } else if (index == 3) {
                  _ouvrir(const ScannerRetraitScreen());
                } else if (index == 4) {
                  _ouvrir(const PortefeuilleCourtierScreen());
                }
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.couleurAccent(context),
              unselectedItemColor: AppTheme.couleurTexteAttenue(context),
              selectedFontSize: 11,
              unselectedFontSize: 11,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Accueil"),
                BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: "Convois"),
                BottomNavigationBarItem(
                  icon: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary,
                    child: Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                  label: "",
                ),
                BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_rounded), label: "Retraits"),
                BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: "Portefeuille"),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _charger,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZonePortefeuilleNeumorphic(
                compact: true,
                titre: "Portefeuille Commissions",
                sousTitre: "Commissions de transit & convois",
                montantSolde: _portefeuille == null
                    ? (_charge ? "Indisponible" : "…")
                    : formaterFcfa(_portefeuille!.soldeDisponible),
                infoSequestre: _portefeuille == null
                    ? "Vos commissions sont versées à la livraison des colis"
                    : "En séquestre : ${formaterFcfa(_portefeuille!.soldeBloque)} • débloqués à la livraison",
                iconeInfo: Icons.security_rounded,
                texteBoutonAction: "Gérer & Retirer mes Fonds",
                onTapAction: () => _ouvrir(const PortefeuilleCourtierScreen()),
                couleurBouton: const [AppTheme.bissap, AppTheme.bissapProfond, AppTheme.bissapProfond],
              ),

              const SizedBox(height: 20),

              // --- ACTION : CRÉER UN GROUPE (texte selon l'activité réelle du courtier) ---
              GestureDetector(
                onTap: () => _ouvrir(const CreerGroupeCourtierScreen()),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.couleurSucces(context),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: AppTheme.olive.withValues(alpha: 0.30), blurRadius: 15, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Icon(Icons.group_add_rounded, color: AppTheme.texteSur(AppTheme.couleurSucces(context)), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _groupes.isEmpty ? "Créer votre 1er groupe d'achat" : "Créer un nouveau groupe d'achat",
                              style: TextStyle(color: AppTheme.texteSur(AppTheme.couleurSucces(context)), fontWeight: FontWeight.w800, fontSize: 14.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _groupes.isEmpty
                                  ? "Fédérez vos commerçants locaux sans avance de trésorerie."
                                  : "${_groupes.length} groupe${_groupes.length > 1 ? 's' : ''} au total • "
                                      "$groupesOuverts ouvert${groupesOuverts > 1 ? 's' : ''}",
                              style: TextStyle(color: AppTheme.texteSur(AppTheme.couleurSucces(context)).withValues(alpha: 0.86), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.texteSur(AppTheme.couleurSucces(context)), size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Convois en cours",
                      style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.couleurTexte(context)),
                    ),
                  ),
                  TextButton(onPressed: () => _ouvrir(const GestionConvoiScreen()), child: const Text("Gérer")),
                ],
              ),
              if (!_charge)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (convoisEnCours.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    child: Column(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 36, color: AppTheme.couleurTexteAttenue(context)),
                        const SizedBox(height: 10),
                        Text("Aucun convoi en cours", style: AppTheme.styleTitrePetit(context)),
                        const SizedBox(height: 4),
                        Text(
                          "Un convoi s'ouvre dès qu'un de vos groupes atteint son objectif.",
                          textAlign: TextAlign.center,
                          style: AppTheme.styleCorpsAttenue(context),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final c in convoisEnCours.take(3))
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => _ouvrir(const GestionConvoiScreen()),
                      leading: const Icon(Icons.local_shipping_rounded),
                      title: Text(
                        groupesParId[c.groupeId]?.produitNom ?? "Groupe #${c.groupeId}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [c.libelleStatut, if (c.dernierEvenement != null) c.dernierEvenement!.localisation].join(" • "),
                      ),
                      trailing: Text(
                        dateRelative(c.dernierEvenement?.date),
                        style: AppTheme.styleCorpsAttenue(context, taille: 11),
                      ),
                    ),
                  ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _ouvrir(const ScannerRetraitScreen()),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text("Scanner un QR Code au retrait", maxLines: 1, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
