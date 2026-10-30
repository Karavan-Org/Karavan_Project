import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/support_plateforme.dart';

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
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.couleurTexte(context)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Coordonnées réelles du support (configurées sur le serveur)
          const CarteSupportPlateforme(),

          const SizedBox(height: 24),

          // FAQ Logistique Courtier
          Text(
            "Protocoles & Déchargement",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.couleurTexte(context)),
          ),
          const SizedBox(height: 12),

          _buildFaqItem(
            context: context,
            question: "Comment valider la remise d'un colis ?",
            reponse: "Dans « Scanner Retrait », scannez le QR code du commerçant ou saisissez son code PIN : la validation se fait en ligne et libère aussitôt le séquestre.",
          ),
          _buildFaqItem(
            context: context,
            question: "Que faire en cas d'avarie ou de colis endommagé ?",
            reponse: "Signalez-le au support Karavan : un administrateur examine le litige et peut déclencher le remboursement du commerçant.",
          ),
          _buildFaqItem(
            context: context,
            question: "Quand les fonds arrivent-ils sur mon portefeuille ?",
            reponse: "À chaque retrait validé, le montant payé par le commerçant quitte le séquestre pour votre portefeuille, frais de plateforme déduits.",
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
