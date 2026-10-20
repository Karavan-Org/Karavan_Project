import '../widgets/tab_navigation_scope.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'scanner_retrait_screen.dart';

/// Écran de gestion et suivi des étapes du convoi (Frame 12, 13 & 14 de la planche)
class GestionConvoiScreen extends StatefulWidget {
  const GestionConvoiScreen({super.key});

  @override
  State<GestionConvoiScreen> createState() => _GestionConvoiScreenState();
}

class _GestionConvoiScreenState extends State<GestionConvoiScreen> {
  int _etapeActuelle = 3; // 1: Enlèvement, 2: Fret, 3: Douane, 4: Dépôt, 5: Retrait

  final List<Map<String, dynamic>> _colis = [];

  void _validerEtapeSuivante() {
    if (_etapeActuelle < 5) {
      setState(() {
        _etapeActuelle++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Étape $_etapeActuelle validée ! Les commerçants ont été notifiés par SMS."),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text("Gestion du Convoi", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.couleurTexte(context))),
        backgroundColor: AppTheme.couleurCarte(context),
        foregroundColor: AppTheme.couleurTexte(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerRetraitScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CARTE RÉCAPITULATIVE DU CONVOI ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.couleurCarte(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.couleurBordure(context)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Convoi Istanbul ➔ Bamako",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.couleurTexte(context)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Étape 3 / 5",
                          style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("Vol Cargo TK-641 • Arrivée estimée dans 48h", style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context))),
                  Divider(height: 24, color: AppTheme.couleurBordure(context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCol("Remplissage", "19 / 40 colis"),
                      _buildInfoCol("Poids Total", "540 kg"),
                      _buildInfoCol("Commissions", "385 000 FCFA", isHighlight: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- ÉTAPES LOGISTIQUES DU CONVOI ---
            Text("Progression de l'Acheminement", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.couleurTexte(context))),
            const SizedBox(height: 12),

            _buildEtapeItem(1, "Enlèvement Istanbul (Laleli)", "Marchandises groupées chez les fournisseurs", true),
            _buildEtapeItem(2, "Embarquement Fret Aérien", "Départ vol cargo vers Bamako-Sénou", true),
            _buildEtapeItem(3, "Arrivée Douane Bamako (Sénou)", "Formalités de dédouanement en cours", _etapeActuelle >= 3, isCurrent: _etapeActuelle == 3),
            _buildEtapeItem(4, "Transfert vers Dépôt Dabanani", "Acheminement final vers le point de retrait", _etapeActuelle >= 4),
            _buildEtapeItem(5, "Mise à disposition au retrait", "SMS avec codes PIN envoyés aux clients", _etapeActuelle >= 5),

            const SizedBox(height: 20),

            // Bouton de validation d'étape (Action Courtier)
            if (_etapeActuelle < 5)
              ElevatedButton.icon(
                onPressed: _validerEtapeSuivante,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _etapeActuelle == 3
                      ? "Valider l'étape : Arrivée Douane Sénou"
                      : "Valider l'étape : Réception au point de retrait",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),

            const SizedBox(height: 26),

            // --- COLIS DÉCLARÉS SOUS VOTRE RESPONSABILITÉ ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Colis des Commerçants (${_colis.length})", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.couleurTexte(context))),
                const Text("Séquestre Karavan Actif", style: TextStyle(fontSize: 11.5, color: AppTheme.success, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),

            if (_colis.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.couleurCarte(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.couleurBordure(context)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.couleurTexteAttenue(context).withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      "Aucun colis rattaché",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Les colis des commerçants s'afficheront ici lors des réservations de fret.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _colis.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final c = _colis[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.couleurCarte(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.couleurBordure(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.tertiary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['client'], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.couleurTexte(context))),
                            const SizedBox(height: 2),
                            Text("${c['articles']} • ${c['poids']}", style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(c['frais'], style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text("Séquestre", style: TextStyle(color: AppTheme.success, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: isHighlight ? AppTheme.primary : AppTheme.couleurTexte(context),
          ),
        ),
      ],
    );
  }

  Widget _buildEtapeItem(int numero, String titre, String detail, bool isDone, {bool isCurrent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isDone
                ? AppTheme.success
                : (isCurrent ? AppTheme.secondary : AppTheme.couleurBordure(context)),
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text("$numero", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isCurrent ? AppTheme.primary : AppTheme.couleurTexte(context))),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
