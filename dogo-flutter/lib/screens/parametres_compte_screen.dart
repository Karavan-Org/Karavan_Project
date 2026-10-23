import 'package:flutter/material.dart';
import '../commercant/code_retrait_commercant_screen.dart';
import '../models/role_acteur.dart';
import '../services/api/api_client.dart';
import '../services/api/api_config.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/changer_mot_de_passe_dialog.dart';

/// Paramètres du compte, communs aux trois rôles. Tout ce qui s'affiche vient du serveur (/api/moi)
/// ou agit réellement : thème, mot de passe, nom, code de retrait. Les informations vérifiées lors du KYC
/// (NIF, RCCM, licence…) sont en lecture seule : elles ne changent qu'avec le support.
class ParametresCompteScreen extends StatefulWidget {
  final RoleActeur role;

  const ParametresCompteScreen({super.key, required this.role});

  @override
  State<ParametresCompteScreen> createState() => _ParametresCompteScreenState();
}

class _ParametresCompteScreenState extends State<ParametresCompteScreen> {
  Map<String, dynamic>? _profil;
  String? _erreur;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = _profil == null;
      _erreur = null;
    });
    try {
      final rep = await ApiClient.instance.get(ApiConfig.moi);
      if (!mounted) return;
      setState(() {
        _profil = rep is Map ? Map<String, dynamic>.from(rep) : null;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e is ApiException ? e.messageComplet : "Impossible de charger votre compte.";
        _chargement = false;
      });
    }
  }

  Future<void> _modifierNom() async {
    final controleur = TextEditingController(text: _profil?['nom']?.toString() ?? '');
    final nouveau = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier mon nom"),
        content: TextField(
          controller: controleur,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: "Nom complet"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, controleur.text.trim()), child: const Text("Enregistrer")),
        ],
      ),
    );
    if (nouveau == null || nouveau.isEmpty || nouveau == _profil?['nom']) return;
    try {
      await ApiClient.instance.patch(ApiConfig.moi, body: {'nom': nouveau});
      await AuthService.instance.rechargerProfil();
      await _charger();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nom mis à jour.")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.danger,
        content: Text(e is ApiException ? e.messageComplet : "Modification impossible."),
      ));
    }
  }

  static String _libelleStatut(String? statut) => switch (statut) {
        'ACTIF' => "Compte actif",
        'EN_ATTENTE' => "En attente de validation",
        'SUSPENDU' => "Suspendu",
        'DESACTIVE' => "Désactivé",
        _ => statut ?? "—",
      };

  /// Informations déclarées à l'inscription, propres au rôle (champs `details` de /api/moi)
  List<(IconData, String, String?)> _informationsMetier(Map<String, dynamic> d) => switch (widget.role) {
        RoleActeur.commercant => [
            (Icons.storefront_rounded, "Boutique", d['nomBoutique']?.toString()),
            (Icons.place_outlined, "Quartier", d['quartierBamako']?.toString()),
            (Icons.local_shipping_outlined, "Adresse de livraison", d['adresseLivraison']?.toString()),
          ],
        RoleActeur.grossiste => [
            (Icons.storefront_rounded, "Boutique / marché", d['nomBoutiqueMarche']?.toString()),
            (Icons.receipt_long_outlined, "NIF", d['numeroNif']?.toString()),
            (Icons.description_outlined, "Registre du commerce", d['registreCommerce']?.toString()),
          ],
        RoleActeur.courtier => [
            (Icons.business_rounded, "Société de transit", d['nomSocieteImport']?.toString()),
            (Icons.badge_outlined, "Licence de transitaire", d['licenceTransit']?.toString()),
            (Icons.warehouse_outlined, "Dépôt", d['adresseDepot']?.toString()),
          ],
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(title: const Text("Paramètres")),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _titre("MON COMPTE"),
            _carte([
              if (_chargement)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (_erreur != null)
                ListTile(
                  leading: const Icon(Icons.cloud_off_rounded, color: AppTheme.danger),
                  title: Text(_erreur!),
                  trailing: TextButton(onPressed: _charger, child: const Text("Réessayer")),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text("Nom"),
                  subtitle: Text(_profil?['nom']?.toString() ?? "—"),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: _modifierNom,
                ),
                _ligne(Icons.phone_iphone_rounded, "Téléphone", _profil?['telephone']?.toString()),
                _ligne(Icons.verified_user_outlined, "Statut", _libelleStatut(_profil?['statut']?.toString())),
                for (final (icone, libelle, valeur) in _informationsMetier(
                    Map<String, dynamic>.from((_profil?['details'] as Map?) ?? const {})))
                  _ligne(icone, libelle, valeur),
              ],
            ]),
            if (widget.role != RoleActeur.commercant && _profil != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  "Ces informations ont été vérifiées avec votre dossier : pour les modifier, contactez le support.",
                  style: AppTheme.styleCorpsAttenue(context, taille: 11.5),
                ),
              ),
            const SizedBox(height: 24),
            _titre("APPARENCE"),
            _carte([
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.instance.themeModeNotifier,
                builder: (context, mode, _) => ListTile(
                  leading: Icon(mode == ThemeMode.dark ? Icons.nightlight_round : Icons.wb_sunny_rounded),
                  title: const Text("Thème de l'application"),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeMode>(
                      value: mode,
                      items: const [
                        DropdownMenuItem(value: ThemeMode.light, child: Text("Clair")),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text("Sombre")),
                        DropdownMenuItem(value: ThemeMode.system, child: Text("Système")),
                      ],
                      onChanged: (m) {
                        if (m != null) ThemeService.instance.changerMode(m);
                      },
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _titre("SÉCURITÉ"),
            _carte([
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text("Mot de passe"),
                subtitle: const Text("Modifier le mot de passe de connexion"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => afficherDialogueChangerMotDePasse(context),
              ),
              if (widget.role == RoleActeur.commercant)
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: const Text("Code de retrait de mes colis"),
                  subtitle: const Text("QR code et PIN à présenter au point de retrait"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const CodeRetraitCommercantScreen())),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _titre(String texte) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(texte, style: AppTheme.styleEtiquette(context, couleur: AppTheme.couleurTexteAttenue(context))),
      );

  Widget _carte(List<Widget> enfants) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (final (i, e) in enfants.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            e,
          ],
        ]),
      );

  Widget _ligne(IconData icone, String libelle, String? valeur) => ListTile(
        leading: Icon(icone),
        title: Text(libelle),
        subtitle: Text(valeur == null || valeur.trim().isEmpty ? "Non renseigné" : valeur),
      );
}
