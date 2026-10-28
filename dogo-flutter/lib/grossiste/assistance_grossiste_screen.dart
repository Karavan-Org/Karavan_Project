import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/support_plateforme.dart';

/// Écran Assistance Grossiste (Support B2B International Karavan)
class AssistanceGrossisteScreen extends StatelessWidget {
  const AssistanceGrossisteScreen({super.key});

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
          "Assistance Fournisseurs",
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Coordonnées réelles du support (configurées sur le serveur)
          const CarteSupportPlateforme(),

          const SizedBox(height: 24),

          // FAQ Grossistes
          Text(
            "Guides & Engagements Grossistes",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.couleurTexte(context)),
          ),
          const SizedBox(height: 12),

          _buildFaqItem(
            context: context,
            question: "Quand dois-je confirmer mon stock (RG-18) ?",
            reponse: "Avant sa publication, chaque groupe monté sur vos produits attend votre confirmation de disponibilité : menu « Disponibilités à valider ».",
          ),
          _buildFaqItem(
            context: context,
            question: "Quand suis-je payé ?",
            reponse: "Pour les groupes que vous portez vous-même, chaque retrait validé verse sur votre portefeuille le montant payé par le commerçant, frais de plateforme déduits. Pour un groupe porté par un courtier, c'est lui qui reçoit les fonds.",
          ),
          _buildFaqItem(
            context: context,
            question: "Comment se passe l'expédition d'un lot ?",
            reponse: "Dès l'objectif atteint, l'onglet « Lots & Ventes » détaille les pièces à préparer. Le courtier prépare puis expédie le lot et publie le suivi du convoi ; pour un groupe que vous portez, signalez vous-même les étapes dans « Suivi des colis ».",
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
          BoxShadow(color: Color(0x062C241E), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Material(type: MaterialType.transparency, borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias, child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.couleurTexte(context)),
        ),
        iconColor: AppTheme.bissap,
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
