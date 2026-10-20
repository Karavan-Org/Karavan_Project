import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/groupe_api_service.dart';
import '../services/lien_groupe.dart';
import '../theme/app_theme.dart';

/// Feuille de partage du lien d'un groupe d'achat : copier, WhatsApp, SMS.
Future<void> afficherPartageGroupe(BuildContext context, GroupeResume groupe) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PartageGroupe(groupe: groupe),
  );
}

class _PartageGroupe extends StatelessWidget {
  final GroupeResume groupe;

  const _PartageGroupe({required this.groupe});

  String get _message => LienGroupe.message(
        groupeId: groupe.id,
        titre: groupe.titre.isNotEmpty ? groupe.titre : groupe.produitNom,
        prixUnitaire: groupe.prixUnitaire,
      );

  Future<void> _copier(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lien copié : collez-le dans vos discussions"), backgroundColor: AppTheme.success),
    );
  }

  Future<void> _ouvrir(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) await _copier(context);
  }

  @override
  Widget build(BuildContext context) {
    final lien = LienGroupe.lien(groupe.id);
    final publie = groupe.statut == 'OUVERT';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5DDD5), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text("Inviter des commerçants",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.couleurTexte(context))),
            const SizedBox(height: 4),
            Text(
              publie
                  ? "Les commerçants qui ouvrent ce lien arrivent directement sur votre groupe."
                  : "Partagez-le dès maintenant : il donnera accès au groupe dès sa publication par dɔgɔ.",
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F2EB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEFE9E0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lien,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
                        Text("Code : ${LienGroupe.code(groupe.id)}",
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Copier",
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.primary),
                    onPressed: () => _copier(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _bouton(
                    icone: Icons.chat_rounded,
                    label: "WhatsApp",
                    couleur: const Color(0xFF25D366),
                    onTap: () => _ouvrir(context, Uri.parse("https://wa.me/?text=${Uri.encodeComponent(_message)}")),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _bouton(
                    icone: Icons.sms_rounded,
                    label: "SMS",
                    couleur: const Color(0xFF1976D2),
                    onTap: () => _ouvrir(context, Uri(scheme: 'sms', queryParameters: {'body': _message})),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _bouton(
                    icone: Icons.link_rounded,
                    label: "Copier",
                    couleur: AppTheme.primary,
                    onTap: () => _copier(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bouton({required IconData icone, required String label, required Color couleur, required VoidCallback onTap}) {
    return Material(
      color: couleur.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icone, color: couleur),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: couleur)),
            ],
          ),
        ),
      ),
    );
  }
}
