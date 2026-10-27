import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../theme/app_theme.dart';

/// Système de pop-up d'information élégant pour notifier l'utilisateur
/// lorsqu'une action a déjà été effectuée ou qu'une opération ne peut pas se faire.
class AppPopups {
  /// Affiche une boîte de dialogue modale d'information
  static Future<void> afficher({
    required BuildContext context,
    required String titre,
    required String message,
    String? detailSupplementaire,
    IconData icone = Icons.info_outline_rounded,
    Color couleurIcone = AppTheme.primary,
    Color? couleurFondIcone,
    String boutonTexte = "J'ai compris",
    VoidCallback? onFermer,
    String? secondBoutonTexte,
    VoidCallback? onSecondBouton,
    bool barrierDismissible = true,
  }) {
    final fondIcone = couleurFondIcone ?? couleurIcone.withValues(alpha: 0.12);

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: "Fermer",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: AppTheme.couleurCarte(ctx),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icône d'en-tête
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: fondIcone,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          icone,
                          size: 34,
                          color: couleurIcone,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Titre
                    Text(
                      titre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.couleurTexte(ctx),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Message principal
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.couleurTexteAttenue(ctx),
                        height: 1.45,
                      ),
                    ),

                    // Détail supplémentaire (si présent)
                    if (detailSupplementaire != null && detailSupplementaire.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.couleurSurfaceDouce(ctx),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.couleurBordure(ctx)),
                        ),
                        child: Text(
                          detailSupplementaire,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.couleurTexteAttenue(ctx),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Bouton(s) d'action
                    Row(
                      children: [
                        if (secondBoutonTexte != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                onSecondBouton?.call();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.couleurTexte(ctx),
                                side: BorderSide(color: AppTheme.couleurBordureForte(ctx)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: Text(
                                secondBoutonTexte,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              onFermer?.call();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: couleurIcone,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Text(
                              boutonTexte,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pop-up spécifique pour les éléments déjà effectués
  static Future<void> afficherActionDejaEffectuee({
    required BuildContext context,
    required String titre,
    required String message,
    String? detail,
    VoidCallback? onFermer,
  }) {
    return afficher(
      context: context,
      titre: titre,
      message: message,
      detailSupplementaire: detail,
      icone: Icons.check_circle_outline_rounded,
      couleurIcone: AppTheme.olive, // Bleu information/action déjà faite
      couleurFondIcone: AppTheme.roseClair,
      boutonTexte: "Fermer et continuer",
      onFermer: onFermer,
    );
  }

  /// Pop-up spécifique pour les opérations qui ne peuvent pas se faire
  static Future<void> afficherActionImpossible({
    required BuildContext context,
    required String titre,
    required String message,
    String? detail,
    VoidCallback? onFermer,
  }) {
    return afficher(
      context: context,
      titre: titre,
      message: message,
      detailSupplementaire: detail,
      icone: Icons.info_outline_rounded,
      couleurIcone: AppTheme.ocreProfond, // Ambre/Orange alerte douce
      couleurFondIcone: AppTheme.ocreClair,
      boutonTexte: "J'ai compris",
      onFermer: onFermer,
    );
  }

  /// Analyse une erreur ou réponse backend (ex: 409 Conflict, 400 Bad Request)
  /// et affiche le pop-up adéquat en langage clair et bienveillant pour l'utilisateur.
  static Future<void> traiterErreurOuConflit(
    BuildContext context,
    Object error, {
    VoidCallback? onFermer,
    VoidCallback? onAllerAuxCommandes,
  }) {
    String msg = "";
    String? code;
    if (error is ApiException) {
      msg = error.messageComplet;
      code = error.code;
    } else {
      msg = error.toString();
    }

    // 1. COMMANDE / PARTICIPATION DÉJÀ ANNULÉE
    if (msg.contains('ANNULEE') ||
        msg.contains('ne peut plus être annulée') ||
        code == 'TRANSITION_INTERDITE' && msg.contains('annul')) {
      return afficherActionDejaEffectuee(
        context: context,
        titre: "Commande déjà annulée",
        message:
            "Cette commande ou participation a déjà été annulée et prise en compte dans votre espace.",
        detail:
            "Si un paiement avait été effectué, la demande de remboursement est déjà transmise et en cours de traitement.",
        onFermer: onFermer,
      );
    }

    // 2. PARTICIPATION DÉJÀ EN COURS DANS CE GROUPE
    if (msg.contains('participez déjà') ||
        (msg.contains('CONFLIT') && msg.contains('variante'))) {
      return afficher(
        context: context,
        titre: "Participation déjà enregistrée",
        message:
            "Vous avez déjà réservé ou rejoint ce groupe d'achat avec cette variante de produit.",
        detailSupplementaire: "Retrouvez l'état de votre commande directement dans votre onglet Commandes.",
        icone: Icons.assignment_turned_in_rounded,
        couleurIcone: AppTheme.primary,
        boutonTexte: "Fermer",
        secondBoutonTexte: onAllerAuxCommandes != null ? "Mes Commandes" : null,
        onSecondBouton: onAllerAuxCommandes,
        onFermer: onFermer,
      );
    }

    // 3. PAIEMENT DÉJÀ EFFECTUÉ OU EN COURS
    if (msg.contains('paiement est déjà en cours') ||
        msg.contains('déjà effectué pour cette participation')) {
      return afficherActionDejaEffectuee(
        context: context,
        titre: "Paiement déjà validé",
        message:
            "Un règlement est déjà enregistré pour cette participation. Votre place est confirmée et garantie sous séquestre.",
        onFermer: onFermer,
      );
    }

    // 4. RÉSERVATION EXPIRÉE
    if (msg.contains('expirée') || msg.contains('EXPIREE') || msg.contains('15 minutes')) {
      return afficherActionImpossible(
        context: context,
        titre: "Délai de réservation expiré",
        message:
            "Le délai alloué pour régler cette réservation est écoulé. Les unités ont été remises à disposition.",
        detail: "Vous pouvez rejoindre à nouveau le groupe d'achat si des lots sont disponibles.",
        onFermer: onFermer,
      );
    }

    // 5. QUOTA DU GROUPE ATTEINT / CLÔTURE
    if (msg.contains('quota') || msg.contains('clôturé') || msg.contains('complet')) {
      return afficherActionImpossible(
        context: context,
        titre: "Achat groupé complet",
        message:
            "Ce groupe d'achat a déjà atteint 100% de son quota et les expéditions sont en préparation.",
        detail: "Il n'est plus possible de modifier ou annuler votre commande à cette étape logistique.",
        onFermer: onFermer,
      );
    }

    // 6. MOYEN DE PAIEMENT REQUIS OU MANQUANT
    if (msg.contains('Aucun moyen de paiement') || msg.contains('Mobile Money')) {
      return afficherActionImpossible(
        context: context,
        titre: "Numéro de paiement requis",
        message:
            "Veuillez renseigner un numéro de téléphone Mobile Money valide (Orange Money, Moov ou Wave) pour valider cette opération.",
        onFermer: onFermer,
      );
    }

    // 7. SOLDE DU PORTEFEUILLE INSUFFISANT
    if (msg.contains('Solde') && msg.contains('insuffisant')) {
      return afficherActionImpossible(
        context: context,
        titre: "Solde portefeuille insuffisant",
        message: msg,
        detail: "Rechargez votre portefeuille d'achats ou utilisez directement un moyen Mobile Money.",
        onFermer: onFermer,
      );
    }

    // 8. AUTRE CAS D'ACTION IMPOSSIBLE OU CONFLIT
    String messageNettoye = msg;
    if (messageNettoye.startsWith('ApiException(')) {
      final reg = RegExp(r'message:\s*([^)]+)');
      final match = reg.firstMatch(messageNettoye);
      if (match != null) {
        messageNettoye = match.group(1)?.trim() ?? messageNettoye;
      }
    }

    return afficherActionImpossible(
      context: context,
      titre: "Information",
      message: messageNettoye,
      onFermer: onFermer,
    );
  }
}
