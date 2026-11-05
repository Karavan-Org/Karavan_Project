import 'package:flutter/material.dart';
import '../models/pays_model.dart';
import '../theme/app_theme.dart';
import 'drapeau_pays_widget.dart';

/// Sélecteur de pays d'origine avec recherche plein texte et support de l'identité Karavan.
class SelecteurPays extends StatelessWidget {
  final List<PaysModel> listePays;
  final PaysModel? paysSelectionne;
  final ValueChanged<PaysModel> onPaysChoisi;
  final String? messageErreur;
  final bool chargement;

  const SelecteurPays({
    super.key,
    required this.listePays,
    required this.paysSelectionne,
    required this.onPaysChoisi,
    this.messageErreur,
    this.chargement = false,
  });

  void _ouvrirDialogue(BuildContext context) {
    if (listePays.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: _FeuilleSelectionPays(
          pays: listePays,
          actuel: paysSelectionne,
          onChoix: (p) {
            Navigator.of(ctx).pop();
            onPaysChoisi(p);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = messageErreur != null
        ? AppTheme.danger
        : AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.public_rounded, size: 16, color: AppTheme.bissap),
            const SizedBox(width: 6),
            Text(
              "Pays d'origine du produit *",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: couleurTexte,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: chargement ? null : () => _ouvrirDialogue(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: couleurCarte,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: couleurBordure, width: 1.2),
            ),
            child: Row(
              children: [
                if (chargement) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bissap),
                  ),
                  const SizedBox(width: 12),
                  Text("Chargement des pays...", style: TextStyle(color: couleurAttenue, fontSize: 14)),
                ] else if (paysSelectionne != null) ...[
                  DrapeauPays(
                    pays: paysSelectionne!.codeIso,
                    largeur: 24,
                    hauteur: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${paysSelectionne!.nomFr} (${paysSelectionne!.codeIso})",
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: couleurTexte,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.bissap, size: 26),
                ] else ...[
                  Icon(Icons.public, size: 20, color: couleurAttenue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Sélectionnez le pays d'origine...",
                      style: TextStyle(
                        fontSize: 14,
                        color: couleurAttenue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down_rounded, color: couleurAttenue, size: 26),
                ],
              ],
            ),
          ),
        ),
        if (messageErreur != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              messageErreur!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.danger,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeuilleSelectionPays extends StatefulWidget {
  final List<PaysModel> pays;
  final PaysModel? actuel;
  final ValueChanged<PaysModel> onChoix;

  const _FeuilleSelectionPays({
    required this.pays,
    required this.actuel,
    required this.onChoix,
  });

  @override
  State<_FeuilleSelectionPays> createState() => _FeuilleSelectionPaysState();
}

class _FeuilleSelectionPaysState extends State<_FeuilleSelectionPays> {
  final TextEditingController _rechercheCtrl = TextEditingController();
  String _filtre = '';

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = AppTheme.estSombre(context);
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);

    final paysFiltres = widget.pays.where((p) {
      if (_filtre.isEmpty) return true;
      final q = _filtre.toLowerCase();
      return p.nomFr.toLowerCase().contains(q) || p.codeIso.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: couleurCarte,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: couleurBordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: couleurBordure,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.public_rounded, color: AppTheme.bissap, size: 22),
              const SizedBox(width: 10),
              Text(
                "Pays d'origine du groupe",
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: couleurTexte,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _rechercheCtrl,
            onChanged: (val) => setState(() => _filtre = val.trim()),
            style: TextStyle(fontSize: 14, color: couleurTexte),
            decoration: InputDecoration(
              hintText: "Rechercher (Chine, Turquie, Émirats, France...)",
              hintStyle: TextStyle(color: couleurAttenue, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: couleurAttenue, size: 20),
              filled: true,
              fillColor: estSombre ? Colors.black12 : const Color(0xFFF6F7F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: couleurBordure),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: couleurBordure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: paysFiltres.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: couleurBordure.withValues(alpha: 0.5)),
              itemBuilder: (ctx, index) {
                final p = paysFiltres[index];
                final estActuel = widget.actuel?.codeIso == p.codeIso;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading: DrapeauPays(
                    pays: p.codeIso,
                    largeur: 26,
                    hauteur: 18,
                  ),
                  title: Text(
                    p.nomFr,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: estActuel ? FontWeight.w800 : FontWeight.w600,
                      color: estActuel ? AppTheme.bissap : couleurTexte,
                    ),
                  ),
                  subtitle: Text(
                    "Code ISO : ${p.codeIso}",
                    style: TextStyle(fontSize: 12, color: couleurAttenue),
                  ),
                  trailing: estActuel
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.bissap, size: 20)
                      : null,
                  onTap: () => widget.onChoix(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
