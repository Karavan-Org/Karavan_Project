import 'package:flutter/material.dart';

/// Écran Assistance Courtier (Support Logistique, Agrément Douanes & Litiges)
class AssistanceCourtierScreen extends StatelessWidget {
  const AssistanceCourtierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C241E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Assistance Courtier",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
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
                            const SnackBar(content: Text("Appel du Desk Logistique DoGo (+223 70 12 34 56)...")),
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
          const Text(
            "Protocoles & Déchargement",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2C241E)),
          ),
          const SizedBox(height: 12),

          _buildFaqItem(
            question: "Comment valider la délivrance d'un colis sans réseau ?",
            reponse: "Saisissez le code PIN dans 'Scanner Retrait'. Il sera synchronisé à la reconnexion.",
          ),
          _buildFaqItem(
            question: "Que faire en cas d'avarie ou colis endommagé au transit ?",
            reponse: "Émettez une réserve sur le bordereau. La garantie DoGo rembourse le colis.",
          ),
          _buildFaqItem(
            question: "Quand les commissions de transit sont-elles transférées ?",
            reponse: "Dès le retrait validé par le commerçant, votre commission est libérée.",
          ),

          const SizedBox(height: 24),

          // Coordonnées Direction Douanes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Permanence Relais Dabanani",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF2C241E)),
                ),
                SizedBox(height: 4),
                Text(
                  "Grand Marché, Bamako\ntransit@dogo.ml • +223 70 88 99 00",
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String reponse}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0646321E), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2C241E)),
        ),
        iconColor: const Color(0xFF9E6738),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Text(
            reponse,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5A493B), height: 1.4),
          ),
        ],
      ),
    );
  }
}
