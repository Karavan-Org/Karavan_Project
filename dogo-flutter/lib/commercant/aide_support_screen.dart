import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/session_storage_service.dart';

/// Écran Aide & Support Commerçant (WhatsApp direct, FAQ et assistance Dogo Mali)
class AideSupportScreen extends StatelessWidget {
  const AideSupportScreen({super.key});

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
          "Aide & Support",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Carte Assistance Rapide WhatsApp
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
                        "Support WhatsApp Karavan Mali",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "Réponse en moins de 15 minutes • 7j/7",
                        style: TextStyle(color: Colors.white, fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Ouverture de l'assistance WhatsApp Karavan Mali (+223 70 00 00 00)...")),
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
                        child: const Text("Démarrer la discussion", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Carte Revoir le Didacticiel Guidé
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.couleurBordure(context)),
              boxShadow: const [
                BoxShadow(color: Color(0x0AF59E0B), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: const Icon(Icons.touch_app_rounded, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Guide Didacticiel Interactif",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.couleurTexte(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Redécouvrez chaque fonctionnalité et bouton pas à pas.",
                        style: TextStyle(fontSize: 11, color: AppTheme.couleurTexteAttenue(context)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    var tel = AuthService.instance.profilActuel?.telephone;
                    if (tel == null || tel.isEmpty) {
                      final profil = await SessionStorageService.instance.lireProfil();
                      tel = profil?.telephone;
                    }
                    tel ??= "defaut";
                    await SessionStorageService.instance.reinitialiserGuide('commercant', tel);
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/commercant', (route) => false);
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF7ED),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Revoir",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // FAQ
          Text(
            "Questions fréquentes (FAQ)",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.couleurTexte(context)),
          ),
          const SizedBox(height: 12),

          _buildFaqItem(
            context,
            question: "Comment mon argent est-il protégé ?",
            reponse: "Votre argent reste bloqué en séquestre jusqu'à la remise de votre colis.",
          ),
          _buildFaqItem(
            context,
            question: "Où puis-je récupérer mes colis ?",
            reponse: "Au point relais du Grand Marché de Bamako. Un SMS vous prévient à l'arrivée.",
          ),
          _buildFaqItem(
            context,
            question: "Que se passe-t-il si un groupe n'atteint pas son objectif ?",
            reponse: "Objectif non atteint ? Vous êtes remboursé à 100 %, sans frais.",
          ),
          _buildFaqItem(
            context,
            question: "Comment changer de mode de paiement ?",
            reponse: "Par Orange Money, Moov Africa ou Wave.",
          ),

          const SizedBox(height: 24),

          // Contact bureau Bamako
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.couleurBordure(context)),
              boxShadow: const [
                BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bureau Karavan Bamako",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.couleurTexte(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  "Dabanani Center, Bamako\ncontact@dogo.ml • +223 76 00 11 22",
                  style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, {required String question, required String reponse}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.couleurBordure(context)),
        boxShadow: const [
          BoxShadow(color: Color(0x0646321E), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Material(type: MaterialType.transparency, borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias, child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.couleurTexte(context)),
        ),
        iconColor: AppTheme.primary,
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
