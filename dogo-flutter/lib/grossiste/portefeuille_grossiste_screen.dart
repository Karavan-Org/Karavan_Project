import 'package:flutter/material.dart';
import '../widgets/portefeuille_professionnel.dart';
import '../widgets/zone_portefeuille_neumorphic.dart';

/// Écran Portefeuille du Grossiste : ventes encaissées, séquestres des groupes qu'il porte et retraits (RG-38, RG-41)
class PortefeuilleGrossisteScreen extends StatefulWidget {
  const PortefeuilleGrossisteScreen({super.key});

  @override
  State<PortefeuilleGrossisteScreen> createState() => _PortefeuilleGrossisteScreenState();
}

class _PortefeuilleGrossisteScreenState extends State<PortefeuilleGrossisteScreen> {
  static const Color _texte = Color(0xFF2C241E);
  static const Color _accent = Color(0xFF9E6738);

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
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _texte),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Portefeuille Grossiste",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _texte),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _texte),
            onPressed: _chargement ? null : _charger,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZonePortefeuilleNeumorphic(
                titre: "Portefeuille Grossiste",
                sousTitre: "Ventes encaissées & séquestres sécurisés",
                montantSolde: _chargement
                    ? "…"
                    : info == null
                        ? "Indisponible"
                        : formatFcfa(info.soldeDisponible),
                infoSequestre: info == null
                    ? "Séquestre DoGo des groupes que vous portez"
                    : "Séquestre en cours : ${formatFcfa(info.soldeBloque)} (lots en transit)",
                iconeInfo: Icons.lock_clock_rounded,
                texteBoutonAction: "Retirer vers Mobile Money",
                onTapAction: info == null ? null : _retirer,
                couleurBouton: const [
                  Color(0xFF3E2B1F),
                  Color(0xFF2A1C14),
                  Color(0xFF1B110B),
                ],
                couleurEmbleme: const [
                  Color(0xFFFFFFFF),
                  Color(0xFFE5A100),
                  Color(0xFF7D4F27),
                ],
              ),
              if (!_chargement && info == null) ...[
                const SizedBox(height: 12),
                const Text(
                  "Portefeuille injoignable : vérifiez votre connexion puis tirez pour actualiser.",
                  style: TextStyle(fontSize: 12.5, color: Color(0xFFC0392B)),
                ),
              ],

              const SizedBox(height: 24),
              const Text(
                "Comptes de versement",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _texte),
              ),
              const SizedBox(height: 10),
              ComptesVersement(moyens: _donnees.moyens),

              const SizedBox(height: 14),
              const Text(
                "Historique des règlements",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _texte),
              ),
              const SizedBox(height: 12),
              HistoriqueMouvementsPro(
                mouvements: _donnees.mouvements,
                messageVide: "Vos encaissements et déblocages séquestres s'afficheront ici.",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
