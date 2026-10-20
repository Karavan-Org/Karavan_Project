import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran Assistance Courtier (Support Logistique, Agrément Douanes & Litiges)
class AssistanceCourtierScreen extends StatelessWidget {
  const AssistanceCourtierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Assistance Courtier",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Carte Support Ligne Directe Bamako
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: Color(0x202E7D32), blurRadius: 14, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF2E7D32), size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Ligne Directe Bamako Transit",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "Desk Douanes & Dépôts Relais • 7j/7",
                        style: TextStyle(color: Colors.white, fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Appel du Desk Logistique Karavan (+223 70 12 34 56)...")),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1B5E20),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text("Contacter le superviseur fret", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // FAQ Logistique Courtier
          Text(
            "Protocoles & Déchargement",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.couleurTexte(context)),
          ),
          const SizedBox(height: 12),

          _buildFaqItem(
            context: context,
            question: "Comment valider la délivrance d'un colis sans réseau ?",
            reponse: "Saisissez le code PIN dans 'Scanner Retrait'. Il sera synchronisé à la reconnexion.",
          ),
          _buildFaqItem(
            context: context,
            question: "Que faire en cas d'avarie ou colis endommagé au transit ?",
            reponse: "Émettez une réserve sur le bordereau. La garantie Karavan rembourse le colis.",
          ),
          _buildFaqItem(
            context: context,
            question: "Quand les commissions de transit sont-elles transférées ?",
            reponse: "Dès le retrait validé par le commerçant, votre commission est libérée.",
          ),

          const SizedBox(height: 24),

          // Coordonnées Direction Douanes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Permanence Relais Dabanani",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.couleurTexte(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  "Grand Marché, Bamako\ntransit@dogo.ml • +223 70 88 99 00",
                  style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({required BuildContext context, required String question, required String reponse}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0646321E), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Material(type: MaterialType.transparency, borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias, child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.couleurTexte(context)),
        ),
        iconColor: const Color(0xFF9E6738),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Text(
            reponse,
            style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context), height: 1.4),
          ),
        ],
      )),
    );
  }
}
