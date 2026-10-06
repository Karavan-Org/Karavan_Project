import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'suivi_colis_service.dart';
import 'code_retrait_commercant_screen.dart';

/// Écran complet de Suivi de Colis pour le Commerçant
/// Affiche la jauge d'avancement calculée strictement sur le nombre d'étapes prescrites
/// à chaque étape validée par le grossiste et notifiée/mise à jour par l'administrateur.
class SuiviColisScreen extends StatelessWidget {
  const SuiviColisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Suivi de Mon Colis",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.textMuted),
            tooltip: "Aide logistique",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Aide logistique DoGo : Contactez le hub Dabanani au +223 70 00 00 00."),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<ColisGroupeModel?>(
        valueListenable: SuiviColisService.instance.colisActifNotifier,
        builder: (context, colis, _) {
          if (colis == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        size: 46,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Aucun colis en cours",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Rejoignez un groupe d'achat pour suivre l'acheminement de vos commandes en temps réel.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final etapes = colis.etapesPrescrites;
          final totalPrescrit = colis.nombreEtapesPrescrites;
          final pct = colis.pourcentageEntier;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. CARTE RÉCAPITULATIVE DU COLIS RATTACHÉ AU GROUPE
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C46321E),
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 80,
                          height: 80,
                          color: const Color(0xFFF7F2EB),
                          child: Image.asset(
                            colis.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined,
                              size: 40,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Groupe : ${colis.idGroupe}",
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF996B00),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              colis.nomProduit,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "N° Commande : ${colis.idCommande} • $totalPrescrit étapes prescrites",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. JAUGE D'AVANCEMENT EN TEMPS RÉEL (CALCULÉE SUR LE NOMBRE D'ÉTAPES DÉDIÉES)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF8A5F3E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2446321E),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "Étape ${colis.etapeActuelle} sur $totalPrescrit prescrites",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  colis.etapeCourante.titre,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "$pct%",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Barre de progression animée fluidement selon le ratio prescrit (k / N)
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: colis.pourcentageProgression),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        builder: (context, value, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 12,
                              backgroundColor: Colors.black.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Segments des N étapes prescrites (générés dynamiquement selon le nombre prescrit)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(totalPrescrit, (index) {
                          final stepNum = index + 1;
                          final estAtteint = stepNum <= colis.etapeActuelle;
                          final estEnCours = stepNum == colis.etapeActuelle;

                          return Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: estAtteint
                                  ? (estEnCours ? AppTheme.secondary : Colors.white)
                                  : Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: estEnCours
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: estAtteint
                                  ? (estEnCours
                                      ? Text(
                                          "$stepNum",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: AppTheme.primary,
                                        ))
                                  : Text(
                                      "$stepNum",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                      ),
                                    ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. BANNIÈRE NOTIFICATION & MISE À JOUR PAR L'ADMINISTRATEUR
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9EC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF996B00),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Validation Grossiste & Notification Admin :",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: Color(0xFF6E4D00),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              colis.derniereMiseAJourAdmin,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A3400),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. CHRONOLOGIE DÉTAILLÉE DES ÉTAPES DU CONVOI
                Text(
                  "Parcours logistique prescrit ($totalPrescrit étapes)",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                ...etapes.map((etape) {
                  final estValidee = etape.numero < colis.etapeActuelle;
                  final estEnCours = etape.numero == colis.etapeActuelle;
                  final estFutur = etape.numero > colis.etapeActuelle;

                  return _buildLigneChronologie(
                    etape: etape,
                    estValidee: estValidee,
                    estEnCours: estEnCours,
                    estFutur: estFutur,
                    estDerniere: etape.numero == etapes.length,
                  );
                }),

                const SizedBox(height: 24),

                // 5. BOUTON ACTION RAPIDE : RETIRER LE COLIS (SI 100%) OU SIMULATION INTERACTIVE
                if (colis.estEntierementLivre)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CodeRetraitCommercantScreen(
                            codeCommande: colis.idCommande,
                            nomProduit: colis.nomProduit,
                            courtierNom: colis.courtierNom,
                            pointRetrait: colis.pointRetrait,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code, size: 22),
                    label: const Text(
                      "Retirer mon colis (QR Code & PIN)",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Bouton de simulation interactive pour tester la validation par le grossiste / admin
                OutlinedButton.icon(
                  onPressed: () {
                    SuiviColisService.instance.avancerEtapeSuivante(context);
                  },
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  label: Text(
                    "Simuler validation étape Grossiste → Admin (${colis.etapeActuelle}/$totalPrescrit)",
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLigneChronologie({
    required EtapeSuiviModel etape,
    required bool estValidee,
    required bool estEnCours,
    required bool estFutur,
    required bool estDerniere,
  }) {
    Color pointColor;
    if (estValidee) {
      pointColor = AppTheme.success;
    } else if (estEnCours) {
      pointColor = AppTheme.secondary;
    } else {
      pointColor = const Color(0xFFD6CBC0);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne indicateur vertical
        Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: pointColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: pointColor, width: 2),
              ),
              child: Icon(
                estValidee ? Icons.check : etape.icone,
                size: 18,
                color: pointColor,
              ),
            ),
            if (!estDerniere)
              Container(
                width: 2.5,
                height: 60,
                color: estValidee ? AppTheme.success : const Color(0xFFE2D8CF),
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Détail textuel de l'étape
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        etape.titre,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: estEnCours || estValidee ? FontWeight.w800 : FontWeight.w600,
                          color: estFutur ? AppTheme.textMuted : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (estEnCours)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "En cours",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A5F00),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  etape.sousTitre,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_pin_outlined, size: 13, color: pointColor),
                    const SizedBox(width: 4),
                    Text(
                      etape.acteurResponsable,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: pointColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      etape.dateHeure,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
