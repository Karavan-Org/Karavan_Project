import 'package:flutter/material.dart';

/// Écran Assistance Grossiste (Support B2B International DoGo)
class AssistanceGrossisteScreen extends StatelessWidget {
  const AssistanceGrossisteScreen({super.key});

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
          "Assistance Fournisseurs",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Carte WhatsApp International Fournisseurs
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF1EBE5D)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: Color(0x2025D366), blurRadius: 14, offset: Offset(0, 4)),
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
                  child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Ligne Directe B2B WhatsApp",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "Support multilingue (Français, English, 中文) • 24/7",
                        style: TextStyle(color: Colors.white, fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Connexion au Support B2B Fournisseurs (+223 70 99 88 77)...")),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1EBE5D),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text("Contacter un gestionnaire B2B", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // FAQ Grossistes
          const Text(
            "Guides & Engagements Grossistes",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2C241E)),
          ),
          const SizedBox(height: 12),

          _buildFaqItem(
            question: "Quel est le délai d'engagement de stock (RG-18) ?",
            reponse: "Objectif atteint : confirmez votre stock sous 24 h pour lancer l'expédition.",
          ),
          _buildFaqItem(
            question: "Quand mon paiement est-il débloqué ?",
            reponse: "Acompte à la remise du lot au transitaire, solde à l'arrivée.",
          ),
          _buildFaqItem(
            question: "Comment organiser le ramassage avec le courtier ?",
            reponse: "Bouton (+) > 'Expédier Lot'. Le transitaire vient récupérer le lot.",
          ),

          const SizedBox(height: 24),

          // Coordonnées desk B2B
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
                  "DoGo Global Sourcing Desk",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF2C241E)),
                ),
                SizedBox(height: 4),
                Text(
                  "Bamako • Guangzhou • Istanbul\nsuppliers@dogo.ml • +223 76 55 44 33",
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
