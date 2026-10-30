import 'package:flutter/material.dart';
import '../grossiste/grossiste_documents_kyc_screen.dart';
import '../models/role_acteur.dart';
import '../services/api/api_exception.dart';
import '../services/kyc_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Dossier de vérification (KYC) réel du Grossiste ou du Courtier : statut, date de dépôt, pièces
/// enregistrées. Un dossier refusé ou absent propose directement un nouveau dépôt.
class MesDocumentsScreen extends StatefulWidget {
  final RoleActeur role;

  const MesDocumentsScreen({super.key, required this.role});

  @override
  State<MesDocumentsScreen> createState() => _MesDocumentsScreenState();
}

class _MesDocumentsScreenState extends State<MesDocumentsScreen> {
  DossierKyc? _dossier;
  bool _charge = false;
  String? _erreur;

  static const _libelles = {
    'PIECE_IDENTITE': ("Pièce d'identité", Icons.badge_outlined),
    'REGISTRE_COMMERCE': ("Registre du commerce (RCCM)", Icons.description_outlined),
    'NIF': ("Attestation NIF", Icons.receipt_long_outlined),
    'LICENCE_TRANSIT': ("Licence de transitaire", Icons.local_shipping_outlined),
    'RELEVE_BANCAIRE': ("Relevé bancaire", Icons.account_balance_outlined),
    'AUTRE': ("Document complémentaire", Icons.attach_file_rounded),
  };

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final d = await KycApiService.instance.monDossier();
      if (!mounted) return;
      setState(() {
        _dossier = d;
        _charge = true;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _charge = true;
        _erreur = e is ApiException ? e.messageComplet : "Impossible de charger votre dossier.";
      });
    }
  }

  Future<void> _deposer() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GrossisteDocumentsKycScreen(role: widget.role, motifRejet: _dossier?.motifRejet),
    ));
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final d = _dossier;
    final (libelleStatut, couleur, icone) = switch (d?.statut) {
      'APPROUVE' => ("Dossier approuvé", AppTheme.couleurSucces(context), Icons.verified_rounded),
      'REJETE' => ("Dossier refusé", AppTheme.danger, Icons.error_outline_rounded),
      'EN_ATTENTE' => ("En cours d'examen", AppTheme.couleurAttention(context), Icons.hourglass_top_rounded),
      _ => ("Aucun dossier déposé", AppTheme.couleurTexteAttenue(context), Icons.folder_off_outlined),
    };

    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(title: const Text("Mes documents")),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (!_charge)
              const Padding(padding: EdgeInsets.only(top: 160), child: Center(child: CircularProgressIndicator()))
            else if (_erreur != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_rounded, color: AppTheme.danger),
                  title: Text(_erreur!),
                  trailing: TextButton(onPressed: _charger, child: const Text("Réessayer")),
                ),
              )
            else ...[
              Card(
                child: ListTile(
                  leading: Icon(icone, color: couleur, size: 30),
                  title: Text(libelleStatut, style: AppTheme.styleTitreMoyen(context, couleur: couleur)),
                  subtitle: Text(d?.dateSoumission != null
                      ? "Déposé ${dateRelative(d!.dateSoumission)}"
                      : "Vos pièces justificatives seront vérifiées par l'équipe conformité."),
                ),
              ),
              if (d?.statut == 'REJETE' && (d?.motifRejet?.isNotEmpty ?? false))
                Card(
                  color: AppTheme.estSombre(context) ? AppTheme.darkDangerSurface : AppTheme.dangerClair,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppTheme.danger),
                    title: const Text("Motif du refus"),
                    subtitle: Text(d!.motifRejet!),
                  ),
                ),
              if (d != null && d.typesDocuments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text("PIÈCES ENREGISTRÉES (${d.typesDocuments.length})",
                      style: AppTheme.styleEtiquette(context, couleur: AppTheme.couleurTexteAttenue(context))),
                ),
                Card(
                  child: Column(children: [
                    for (final (i, type) in d.typesDocuments.indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: Icon(_libelles[type]?.$2 ?? Icons.insert_drive_file_outlined),
                        title: Text(_libelles[type]?.$1 ?? type),
                        trailing: Icon(
                          d.statut == 'APPROUVE' ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          color: d.statut == 'APPROUVE' ? AppTheme.couleurSucces(context) : AppTheme.couleurTexteAttenue(context),
                          size: 20,
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
              if (d == null || d.statut == 'REJETE') ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _deposer,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(d == null ? "Déposer mon dossier" : "Déposer un nouveau dossier"),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
