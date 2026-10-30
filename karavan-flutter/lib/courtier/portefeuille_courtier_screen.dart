import '../widgets/tab_navigation_scope.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/portefeuille_professionnel.dart';
import '../widgets/zone_portefeuille_neumorphic.dart';

/// Écran Portefeuille Courtier (Frame 17 de la planche) : solde réel, séquestre, comptes et retraits (RG-38, RG-41)
class PortefeuilleCourtierScreen extends StatefulWidget {
  const PortefeuilleCourtierScreen({super.key});

  @override
  State<PortefeuilleCourtierScreen> createState() => _PortefeuilleCourtierScreenState();
}

class _PortefeuilleCourtierScreenState extends State<PortefeuilleCourtierScreen> {
  static const Color _accent = AppTheme.bissapProfond;

  DonneesPortefeuillePro _donnees = const DonneesPortefeuillePro();
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final donnees = await DonneesPortefeuillePro.charger();
    if (!mounted) return;
    setState(() {
      _donnees = donnees;
      _chargement = false;
    });
  }

  Future<void> _retirer() async {
    final info = _donnees.info;
    if (info == null) return;
    final ok = await demanderRetraitPortefeuille(
      context,
      soldeDisponible: info.soldeDisponible,
      moyens: _donnees.moyens,
      accent: _accent,
    );
    if (ok) await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final info = _donnees.info;
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),
        title: Text("Portefeuille Courtier", style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.couleurTexte(context))),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.couleurTexte(context),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _chargement ? null : _charger)],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZonePortefeuilleNeumorphic(
                titre: "Portefeuille Courtier",
                sousTitre: "Commissions de transit & convois sécurisées",
                montantSolde: _chargement
                    ? "…"
                    : info == null
                        ? "Indisponible"
                        : formatFcfa(info.soldeDisponible),
                infoSequestre: info == null
                    ? "Garantie Séquestre Karavan • Commissions débloquées à la livraison"
                    : "En séquestre : ${formatFcfa(info.soldeBloque)} • débloqué à la livraison",
                iconeInfo: Icons.security_rounded,
                texteBoutonAction: "Retirer vers Mobile Money",
                onTapAction: info == null ? null : _retirer,
                couleurBouton: const [
                  AppTheme.bissap,
                  AppTheme.bissapProfond,
                  AppTheme.bissapProfond,
                ],
              ),
              if (!_chargement && info == null) ...[
                const SizedBox(height: 12),
                const Text(
                  "Portefeuille injoignable : vérifiez votre connexion puis tirez pour actualiser.",
                  style: TextStyle(fontSize: 12.5, color: AppTheme.danger),
                ),
              ],

              const SizedBox(height: 24),
              Text("Comptes de Versement Associés", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.couleurTexte(context))),
              const SizedBox(height: 10),
              ComptesVersement(moyens: _donnees.moyens),

              const SizedBox(height: 14),
              Text("Historique des Mouvements", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.couleurTexte(context))),
              const SizedBox(height: 10),
              HistoriqueMouvementsPro(
                mouvements: _donnees.mouvements,
                messageVide: "Vos commissions de transit apparaîtront ici dès l'arrivée des premiers convois.",
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
