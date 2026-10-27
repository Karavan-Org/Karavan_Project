import 'package:flutter/material.dart';
import '../services/profil_api_service.dart';
import '../services/api/api_exception.dart';
import '../theme/app_theme.dart';

/// Section réutilisable de gestion des numéros Mobile Money (RG-10, GET/POST/PUT/DELETE /api/moi/moyens-paiement)
class MoyensPaiementSection extends StatefulWidget {
  const MoyensPaiementSection({super.key});

  @override
  State<MoyensPaiementSection> createState() => _MoyensPaiementSectionState();
}

class _MoyensPaiementSectionState extends State<MoyensPaiementSection> {
  bool _chargement = true;
  String? _erreur;
  List<MoyenPaiementItem> _moyens = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final data = await ProfilApiService.instance.mesMoyensPaiement();
      if (!mounted) return;
      setState(() {
        _moyens = data;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : "Impossible de charger les moyens de paiement.";
        _chargement = false;
      });
    }
  }

  static String _nomOperateur(String op) => switch (op) {
        'ORANGE_MONEY' => 'Orange Money',
        'MOOV_MONEY' => 'Moov Money',
        'WAVE' => 'Wave',
        _ => op,
      };

  static Color _couleurOperateur(String op) => switch (op) {
        'ORANGE_MONEY' => const Color(0xFFFF6600),
        'MOOV_MONEY' => const Color(0xFF005BA6),
        'WAVE' => const Color(0xFF1BA6E8),
        _ => AppTheme.primary,
      };

  Future<void> _ajouterMoyen() async {
    final numCtrl = TextEditingController(text: "+223 ");
    String operateur = "ORANGE_MONEY";
    bool parDefaut = _moyens.isEmpty;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Nouveau numéro Mobile Money", style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Numéro de téléphone",
                  hintText: "+223 70 00 00 00",
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: operateur,
                decoration: const InputDecoration(labelText: "Opérateur"),
                items: const [
                  DropdownMenuItem(value: "ORANGE_MONEY", child: Text("Orange Money 🇲🇱")),
                  DropdownMenuItem(value: "MOOV_MONEY", child: Text("Moov Money 🇲🇱")),
                  DropdownMenuItem(value: "WAVE", child: Text("Wave 🇲🇱")),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => operateur = val);
                },
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Définir par défaut", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: parDefaut,
                onChanged: (val) => setDialogState(() => parDefaut = val ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Ajouter"),
            ),
          ],
        ),
      ),
    );

    final numero = numCtrl.text.trim();
    numCtrl.dispose();
    if (ok != true || numero.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ProfilApiService.instance.ajouterMoyenPaiement(
        numero: numero,
        operateur: operateur,
        parDefaut: parDefaut,
      );
      messenger.showSnackBar(
        SnackBar(content: Text("Numéro $numero ajouté"), backgroundColor: AppTheme.success),
      );
      _charger();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : "Erreur lors de l'ajout : $e"),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _definirParDefaut(MoyenPaiementItem m) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ProfilApiService.instance.definirMoyenParDefaut(m.id);
      messenger.showSnackBar(
        SnackBar(content: Text("${m.numero} défini comme numéro par défaut"), backgroundColor: AppTheme.success),
      );
      _charger();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : "Erreur : $e"),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _supprimer(MoyenPaiementItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Supprimer le numéro ?"),
        content: Text("Voulez-vous supprimer le numéro ${m.numero} (${_nomOperateur(m.operateur)}) ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ProfilApiService.instance.supprimerMoyenPaiement(m.id);
      messenger.showSnackBar(
        const SnackBar(content: Text("Numéro supprimé avec succès"), backgroundColor: AppTheme.success),
      );
      _charger();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : "Impossible de supprimer : $e"),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "NUMÉROS MOBILE MONEY",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.couleurTexteAttenue(context), letterSpacing: 0.8),
            ),
            TextButton.icon(
              onPressed: _ajouterMoyen,
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Ajouter", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.couleurCarte(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x062C241E), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: _chargement
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _erreur != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_erreur!, style: const TextStyle(fontSize: 12))),
                          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _charger),
                        ],
                      ),
                    )
                  : _moyens.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.phone_android_outlined, size: 36, color: AppTheme.textePale),
                              const SizedBox(height: 8),
                              Text("Aucun numéro Mobile Money enregistré.", style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context))),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _ajouterMoyen,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("Ajouter un numéro"),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _moyens.length,
                          separatorBuilder: (_, __) => Divider(height: 1, indent: 56, color: AppTheme.couleurBordure(context)),
                          itemBuilder: (context, i) {
                            final m = _moyens[i];
                            final opColor = _couleurOperateur(m.operateur);
                            return ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: opColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.phone_android_rounded, color: opColor, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Text(m.numero, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  if (m.parDefaut) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text("Défaut", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.couleurSucces(context))),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(_nomOperateur(m.operateur), style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context))),
                              trailing: PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, size: 20, color: AppTheme.couleurTexteAttenue(context)),
                                onSelected: (val) {
                                  if (val == 'defaut') _definirParDefaut(m);
                                  if (val == 'supprimer') _supprimer(m);
                                },
                                itemBuilder: (ctx) => [
                                  if (!m.parDefaut)
                                    const PopupMenuItem(value: 'defaut', child: Text("Définir par défaut")),
                                  const PopupMenuItem(
                                    value: 'supprimer',
                                    child: Text("Supprimer", style: TextStyle(color: AppTheme.danger)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
