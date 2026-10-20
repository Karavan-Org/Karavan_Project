import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/paiement_api_service.dart';
import '../services/portefeuille_api_service.dart';
import '../services/profil_api_service.dart';
import '../theme/app_theme.dart';
import 'app_popups.dart';

/// Briques communes aux portefeuilles du Courtier et du Grossiste (RG-38, RG-41) :
/// solde réel, séquestre bloqué, comptes de versement, historique et retrait vers Mobile Money.

String formatFcfa(num montant) {
  final texte = montant.round().toString();
  final groupes = texte.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  return '$groupes FCFA';
}

String libelleOperateur(String code) => switch (code) {
      'ORANGE_MONEY' => 'Orange Money',
      'MOOV_MONEY' => 'Moov Money',
      'WAVE' => 'Wave',
      _ => code,
    };

/// Instantané du portefeuille et des comptes de versement de l'utilisateur connecté.
class DonneesPortefeuillePro {
  final PortefeuilleInfo? info;
  final List<MouvementPortefeuille> mouvements;
  final List<MoyenPaiementItem> moyens;

  const DonneesPortefeuillePro({this.info, this.mouvements = const [], this.moyens = const []});

  bool get indisponible => info == null;

  static Future<DonneesPortefeuillePro> charger() async {
    final resultats = await Future.wait([
      PortefeuilleApiService.instance.voirPortefeuille(),
      PortefeuilleApiService.instance.mesMouvements(),
      ProfilApiService.instance.mesMoyensPaiement().catchError((_) => <MoyenPaiementItem>[]),
    ]);
    return DonneesPortefeuillePro(
      info: resultats[0] as PortefeuilleInfo?,
      mouvements: resultats[1] as List<MouvementPortefeuille>,
      moyens: resultats[2] as List<MoyenPaiementItem>,
    );
  }
}

/// Dialogue de retrait du solde disponible. Renvoie vrai si le retrait a été accepté par le serveur.
Future<bool> demanderRetraitPortefeuille(
  BuildContext context, {
  required double soldeDisponible,
  required List<MoyenPaiementItem> moyens,
  Color accent = AppTheme.primary,
}) async {
  if (moyens.isEmpty) {
    await AppPopups.afficherActionImpossible(
      context: context,
      titre: 'Aucun compte de versement',
      message: 'Ajoutez un numéro Mobile Money dans vos paramètres pour recevoir vos retraits.',
    );
    return false;
  }
  if (soldeDisponible <= 0) {
    await AppPopups.afficherActionImpossible(
      context: context,
      titre: 'Solde disponible nul',
      message: 'Les fonds du séquestre deviennent disponibles au retrait une fois les marchandises remises.',
    );
    return false;
  }

  final moyenVerse = await showDialog<MoyenPaiementItem>(
    context: context,
    builder: (_) => _DialogueRetrait(soldeDisponible: soldeDisponible, moyens: moyens, accent: accent),
  );

  if (moyenVerse != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retrait envoyé vers ${libelleOperateur(moyenVerse.operateur)} (${moyenVerse.numero}).'),
        backgroundColor: AppTheme.success,
      ),
    );
  }
  return moyenVerse != null;
}

/// Saisie du retrait ; se ferme en renvoyant le compte crédité, ou null si l'utilisateur renonce.
class _DialogueRetrait extends StatefulWidget {
  final double soldeDisponible;
  final List<MoyenPaiementItem> moyens;
  final Color accent;

  const _DialogueRetrait({required this.soldeDisponible, required this.moyens, required this.accent});

  @override
  State<_DialogueRetrait> createState() => _DialogueRetraitState();
}

class _DialogueRetraitState extends State<_DialogueRetrait> {
  late final TextEditingController _montant =
      TextEditingController(text: widget.soldeDisponible.round().toString());
  late MoyenPaiementItem _moyen = widget.moyens.firstWhere((m) => m.parDefaut, orElse: () => widget.moyens.first);
  // Une clé par demande : relancer après une coupure réseau ne verse jamais deux fois
  final String _cle = PaiementApiService.instance.genererCleIdempotence();
  String? _erreur;
  bool _envoi = false;

  @override
  void dispose() {
    _montant.dispose();
    super.dispose();
  }

  Future<void> _confirmer() async {
    final montant = double.tryParse(_montant.text) ?? 0;
    if (montant <= 0 || montant > widget.soldeDisponible) {
      setState(() => _erreur = 'Entre 1 et ${formatFcfa(widget.soldeDisponible)}');
      return;
    }
    setState(() {
      _erreur = null;
      _envoi = true;
    });
    try {
      await PortefeuilleApiService.instance
          .retirer(montant: montant, moyenPaiementId: _moyen.id, cleIdempotence: _cle);
      if (mounted) Navigator.of(context).pop(_moyen);
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      await AppPopups.traiterErreurOuConflit(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Retrait vers Mobile Money', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Disponible : ${formatFcfa(widget.soldeDisponible)}',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: _montant,
            enabled: !_envoi,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Montant (FCFA)', errorText: _erreur),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _moyen.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Compte de versement'),
            items: [
              for (final m in widget.moyens)
                DropdownMenuItem(
                  value: m.id,
                  child: Text('${libelleOperateur(m.operateur)} • ${m.numero}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _envoi ? null : (id) => setState(() => _moyen = widget.moyens.firstWhere((m) => m.id == id)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.accent, foregroundColor: Colors.white),
          onPressed: _envoi ? null : _confirmer,
          child: _envoi
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirmer le retrait'),
        ),
      ],
    );
  }
}

/// Comptes Mobile Money sur lesquels les retraits sont versés.
class ComptesVersement extends StatelessWidget {
  final List<MoyenPaiementItem> moyens;

  const ComptesVersement({super.key, required this.moyens});

  @override
  Widget build(BuildContext context) {
    if (moyens.isEmpty) {
      return const Text('Aucun compte enregistré : ajoutez un numéro Mobile Money dans vos paramètres.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted));
    }
    return Column(
      children: [
        for (final m in moyens)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.couleurBordure(context)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.tertiary.withValues(alpha: 0.4),
                  child: const Icon(Icons.phone_android_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(libelleOperateur(m.operateur),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.couleurTexte(context))),
                      Text(m.numero, style: TextStyle(color: AppTheme.couleurTexteAttenue(context), fontSize: 12)),
                    ],
                  ),
                ),
                if (m.parDefaut)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Par défaut',
                        style: TextStyle(color: AppTheme.success, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Historique des mouvements du portefeuille, du plus récent au plus ancien.
class HistoriqueMouvementsPro extends StatelessWidget {
  final List<MouvementPortefeuille> mouvements;
  final String messageVide;

  const HistoriqueMouvementsPro({super.key, required this.mouvements, required this.messageVide});

  static ({String titre, bool entree}) _sens(String type) => switch (type) {
        'BLOCAGE_SEQUESTRE' => (titre: 'Paiement reçu en séquestre', entree: true),
        'LIBERATION_SEQUESTRE' => (titre: 'Séquestre débloqué', entree: true),
        'RECHARGE_PORTEFEUILLE' => (titre: 'Recharge', entree: true),
        'FRAIS_PLATEFORME' => (titre: 'Frais de plateforme Karavan', entree: false),
        'REMBOURSEMENT' => (titre: 'Remboursement commerçant', entree: false),
        'RETRAIT_COURTIER' => (titre: 'Retrait vers Mobile Money', entree: false),
        'DEBIT_COMMERCANT' => (titre: 'Paiement de commande', entree: false),
        _ => (titre: type, entree: true),
      };

  @override
  Widget build(BuildContext context) {
    if (mouvements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.couleurCarte(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.couleurBordure(context), width: 1.2),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('Aucun mouvement pour le moment',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context))),
            const SizedBox(height: 4),
            Text(messageVide,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context))),
          ],
        ),
      );
    }
    final tries = [...mouvements]
      ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    return Column(
      children: [
        for (final m in tries)
          Builder(builder: (context) {
            final sens = _sens(m.type);
            final couleur = sens.entree ? AppTheme.success : const Color(0xFFC62828);
            final d = m.date?.toLocal();
            final date = d == null
                ? ''
                : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.couleurCarte(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.couleurBordure(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: couleur.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(sens.entree ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: couleur, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sens.titre,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.couleurTexte(context))),
                        const SizedBox(height: 2),
                        Text([date, m.reference].where((s) => s.isNotEmpty).join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${sens.entree ? '+' : '-'}${formatFcfa(m.montant)}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: couleur)),
                ],
              ),
            );
          }),
      ],
    );
  }
}
