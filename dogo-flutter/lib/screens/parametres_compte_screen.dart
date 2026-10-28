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
import '../widgets/selecteur_emplacement_carte_dialog.dart';

/// Paramètres du compte pour Commerçant, Grossiste et Courtier.
/// Permet de modifier le nom, la boutique/société et l'emplacement par carte ou coordonnées GPS.
/// Les documents légaux vérifiés lors du KYC (NIF, RCCM, licence) restent en lecture seule.
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

  Map<String, dynamic> get _details =>
      Map<String, dynamic>.from((_profil?['details'] as Map?) ?? const {});

  String get _nomStructureActuel {
    final d = _details;
    return switch (widget.role) {
      RoleActeur.commercant => d['nomBoutique']?.toString() ?? '',
      RoleActeur.grossiste => d['nomBoutiqueMarche']?.toString() ?? '',
      RoleActeur.courtier => d['nomSocieteImport']?.toString() ?? '',
    };
  }

  String get _libelleChampStructure => switch (widget.role) {
        RoleActeur.commercant => "Nom de la boutique",
        RoleActeur.grossiste => "Nom de la boutique / marché",
        RoleActeur.courtier => "Nom de la société de transit",
      };

  String get _quartierOuAdresseActuel {
    final d = _details;
    final val = switch (widget.role) {
      RoleActeur.commercant => d['quartierBamako'] ?? d['adresseLivraison'],
      RoleActeur.grossiste => d['quartierMarche'] ?? d['nomBoutiqueMarche'],
      RoleActeur.courtier => d['adresseDepot'] ?? d['quartierBamako'],
    };
    return val?.toString() ?? '';
  }

  double? get _latitudeActuelle {
    final v = _details['latitude'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  double? get _longitudeActuelle {
    final v = _details['longitude'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
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

  Future<void> _modifierNomStructure() async {
    final libelle = _libelleChampStructure;
    final controleur = TextEditingController(text: _nomStructureActuel);
    final nouveau = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Modifier $libelle"),
        content: TextField(
          controller: controleur,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: libelle),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, controleur.text.trim()), child: const Text("Enregistrer")),
        ],
      ),
    );
    if (nouveau == null || nouveau.isEmpty || nouveau == _nomStructureActuel) return;
    try {
      final corps = <String, dynamic>{
        'nomBoutique': nouveau,
        'nomBoutiqueMarche': nouveau,
        'nomSocieteImport': nouveau,
      };
      await ApiClient.instance.patch(ApiConfig.moi, body: corps);
      await AuthService.instance.rechargerProfil();
      await _charger();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$libelle mis à jour avec succès.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.danger,
        content: Text(e is ApiException ? e.messageComplet : "Modification impossible."),
      ));
    }
  }

  Future<void> _appliquerEmplacement(DonneesEmplacement d) async {
    try {
      final corps = <String, dynamic>{
        'latitude': d.latitude,
        'longitude': d.longitude,
        'quartierBamako': d.quartier,
        'adresseLivraison': d.quartier,
        'adresseDepot': d.quartier,
      };
      await ApiClient.instance.patch(ApiConfig.moi, body: corps);
      await AuthService.instance.rechargerProfil();
      await _charger();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Emplacement géographique enregistré.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.danger,
        content: Text(e is ApiException ? e.messageComplet : "Enregistrement impossible."),
      ));
    }
  }

  Future<void> _choisirEmplacementSurCarte() async {
    final resultat = await SelecteurEmplacementCarteDialog.ouvrir(
      context: context,
      titre: widget.role == RoleActeur.courtier
          ? "Localisation du dépôt transit"
          : "Emplacement de votre boutique",
      quartierInitial: _quartierOuAdresseActuel.isNotEmpty ? _quartierOuAdresseActuel : null,
      latitudeInitiale: _latitudeActuelle,
      longitudeInitiale: _longitudeActuelle,
    );

    if (resultat != null) {
      await _appliquerEmplacement(resultat);
    }
  }

  Future<void> _saisirCoordonneesDirectes() async {
    final resultat = await SaisieCoordonneesDialog.ouvrir(
      context: context,
      titre: "Coordonnées de l'emplacement",
      quartierInitial: _quartierOuAdresseActuel,
      latitudeInitiale: _latitudeActuelle,
      longitudeInitiale: _longitudeActuelle,
    );

    if (resultat != null) {
      await _appliquerEmplacement(resultat);
    }
  }

  static String _libelleStatut(String? statut) => switch (statut) {
        'ACTIF' => "Compte actif",
        'EN_ATTENTE' => "En attente de validation",
        'SUSPENDU' => "Suspendu",
        'DESACTIVE' => "Désactivé",
        _ => statut ?? "—",
      };

  /// Documents officiels / KYC du rôle
  List<(IconData, String, String?)> _documentsKyc(Map<String, dynamic> d) => switch (widget.role) {
        RoleActeur.grossiste => [
            (Icons.receipt_long_outlined, "Numéro NIF", d['numeroNif']?.toString()),
            (Icons.description_outlined, "Registre du commerce", d['registreCommerce']?.toString()),
          ],
        RoleActeur.courtier => [
            (Icons.badge_outlined, "Licence de transitaire", d['licenceTransit']?.toString()),
          ],
        RoleActeur.commercant => const [],
      };

  @override
  Widget build(BuildContext context) {
    final nomStructure = _nomStructureActuel;
    final adresse = _quartierOuAdresseActuel;
    final lat = _latitudeActuelle;
    final lng = _longitudeActuelle;
    final coordsDefinies = lat != null && lng != null;
    final docsLegaux = _documentsKyc(_details);

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
              ],
            ]),

            const SizedBox(height: 24),
            _titre(widget.role == RoleActeur.courtier ? "SOCIÉTÉ & DÉPÔT" : "BOUTIQUE & EMPLACEMENT"),
            _carte([
              ListTile(
                leading: Icon(
                  widget.role == RoleActeur.courtier
                      ? Icons.business_rounded
                      : Icons.storefront_rounded,
                  color: AppTheme.doreKaravan,
                ),
                title: Text(_libelleChampStructure),
                subtitle: Text(
                  nomStructure.isNotEmpty ? nomStructure : "À configurer",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: nomStructure.isNotEmpty ? null : AppTheme.danger,
                  ),
                ),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: _modifierNomStructure,
              ),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text("Quartier / Adresse de repère"),
                subtitle: Text(adresse.isNotEmpty ? adresse : "Non renseigné"),
              ),
              ListTile(
                leading: const Icon(Icons.my_location_rounded),
                title: const Text("Coordonnées géographiques"),
                subtitle: Text(
                  coordsDefinies
                      ? "${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}"
                      : "Non positionné sur la carte",
                  style: TextStyle(
                    fontWeight: coordsDefinies ? FontWeight.w600 : FontWeight.normal,
                    color: coordsDefinies ? null : AppTheme.danger,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text(
                          "Pointer sur la carte",
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _choisirEmplacementSurCarte,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                        label: const Text(
                          "Saisir coordonnées",
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saisirCoordonneesDirectes,
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            if (docsLegaux.isNotEmpty) ...[
              const SizedBox(height: 24),
              _titre("DOCUMENTS & KYC"),
              _carte([
                for (final (icone, libelle, valeur) in docsLegaux)
                  _ligne(icone, libelle, valeur),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  "Ces pièces ont été vérifiées avec votre dossier : pour les modifier, contactez le support.",
                  style: AppTheme.styleCorpsAttenue(context, taille: 11.5),
                ),
              ),
            ],

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
