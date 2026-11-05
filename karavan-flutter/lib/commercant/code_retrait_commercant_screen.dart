import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api/api_exception.dart';
import '../services/logistique_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/itineraire_depot.dart';

/// Écran du Code de Retrait (QR) sécurisé pour le Commerçant (RG-53, RG-71)
/// - QR opaque noir sur blanc (qr_flutter)
/// - Luminosité poussée au maximum pour faciliter le scan au guichet
/// - Écran maintenu allumé (Wakelock)
/// - Code court de secours à 8 chiffres affiché clairement sous le QR
/// - Bouton « Générer un nouveau code » (avec confirmation)
/// - Affichable même hors-ligne une fois chargé
class CodeRetraitCommercantScreen extends StatefulWidget {
  final String codeCommande;
  final String? codePin;
  final String nomProduit;
  final int quantite;
  final String pointRetrait;
  final String courtierNom;

  const CodeRetraitCommercantScreen({
    super.key,
    this.codeCommande = "",
    this.codePin,
    this.nomProduit = "Commande groupée",
    this.quantite = 1,
    this.pointRetrait = "Point de retrait Karavan Bamako",
    this.courtierNom = "Service Transit Karavan",
  });

  @override
  State<CodeRetraitCommercantScreen> createState() => _CodeRetraitCommercantScreenState();
}

class _CodeRetraitCommercantScreenState extends State<CodeRetraitCommercantScreen> {
  static const _rouge = AppTheme.danger;
  bool _chargement = true;
  bool _actionEnCours = false;
  String? _erreur;
  List<Map<String, dynamic>> _aRetirer = [];
  Map<String, dynamic>? _commande;
  CodeRetraitDonnees? _code;

  @override
  void initState() {
    super.initState();
    _pousserLuminosite();
    _charger();
  }

  @override
  void dispose() {
    _restaurerLuminosite();
    super.dispose();
  }

  Future<void> _pousserLuminosite() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (_) {}
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _restaurerLuminosite() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  /// Commande demandée par l'écran appelant, sinon les commandes EN_ATTENTE_RETRAIT du commerçant
  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final aRetirer = await LogistiqueApiService.instance.commandesARetirer();
      final demandee = int.tryParse(widget.codeCommande.replaceAll(RegExp(r'[^0-9]'), ''));
      final choisie = aRetirer.where((c) => (c['id'] as num?)?.toInt() == demandee).firstOrNull ??
          (demandee != null
              ? {
                  'id': demandee,
                  'produit': widget.nomProduit,
                  'quantite': widget.quantite,
                  'pointRetrait': {'nom': widget.pointRetrait},
                }
              : (aRetirer.length == 1 ? aRetirer.first : null));
      if (!mounted) return;
      setState(() {
        _aRetirer = aRetirer;
        _chargement = false;
      });
      if (choisie != null) {
        await _choisir(choisie);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e is ApiException ? e.messageComplet : 'Impossible de charger vos commandes : $e';
      });
    }
  }

  Future<void> _choisir(Map<String, dynamic> commande) async {
    setState(() {
      _commande = commande;
      _code = null;
      _chargement = true;
      _erreur = null;
    });
    try {
      final code = await LogistiqueApiService.instance.obtenirCodeRetrait(commande['id']);
      if (!mounted) return;
      setState(() {
        _code = code;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e is ApiException ? e.messageComplet : 'Code de retrait indisponible : $e';
      });
    }
  }

  Future<void> _demanderRegeneration() async {
    if (_commande == null || _actionEnCours) return;
    final commandeId = _commande!['id'];

    final confirmation = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.couleurCarte(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Générer un nouveau code ?",
          style: TextStyle(
            fontFamily: AppTheme.policeTitre,
            fontWeight: FontWeight.w700,
            color: AppTheme.couleurTexte(ctx),
          ),
        ),
        content: Text(
          "L'ancien QR code et son code court seront immédiatement invalidés. Cette action est irréversible.",
          style: TextStyle(color: AppTheme.couleurTexteAttenue(ctx), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Annuler", style: TextStyle(color: AppTheme.couleurTexteAttenue(ctx))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Oui, générer"),
          ),
        ],
      ),
    );

    if (confirmation != true) return;

    setState(() => _actionEnCours = true);
    try {
      final nouveau = await LogistiqueApiService.instance.regenererCodeRetrait(commandeId);
      if (!mounted) return;
      setState(() {
        _code = nouveau;
        _actionEnCours = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nouveau code de retrait généré avec succès"),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.messageComplet : 'Erreur lors de la régénération : $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  String get _nomProduit => (_commande?['produit'] as String?) ?? widget.nomProduit;
  int get _quantite => (_commande?['quantite'] as num?)?.toInt() ?? widget.quantite;
  String get _pointRetrait {
    final point = _commande?['pointRetrait'];
    if (point is Map && point['nom'] != null) {
      return [point['nom'], point['adresse']].whereType<String>().where((s) => s.isNotEmpty).join(' — ');
    }
    return widget.pointRetrait;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        title: const Text(
          "Mon code de retrait",
          style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.couleurCarte(context),
        elevation: 0,
        foregroundColor: AppTheme.couleurTexte(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: (_chargement || _actionEnCours) ? null : _charger,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              if (_chargement)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_code == null)
                _etatSansCode()
              else ...[
                _carteQr(_code!),
                const SizedBox(height: 20),
                _carteLieu(),
              ],
              const SizedBox(height: 24),
              // Sécurité et déblocage séquestre
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.couleurSurfaceDouce(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.couleurAccent(context), size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        "Vos fonds restent en séquestre jusqu'à la remise physique de votre colis.",
                        style: TextStyle(fontSize: 11.5, height: 1.35, color: AppTheme.couleurTexte(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Erreur, aucune commande prête, ou plusieurs commandes à choisir
  Widget _etatSansCode() {
    if (_erreur != null) {
      return _message(Icons.error_outline_rounded, _erreur!, _rouge);
    }
    if (_aRetirer.isEmpty) {
      return _message(
        Icons.local_shipping_outlined,
        "Aucune commande n'est encore prête à être retirée. Votre code de retrait (QR) apparaîtra ici dès que votre colis sera "
        "disponible au point de retrait.",
        AppTheme.couleurTexteAttenue(context),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Choisissez la commande à retirer",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.couleurTexte(context)),
        ),
        const SizedBox(height: 12),
        ..._aRetirer.map((c) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primary),
                title: Text(
                  "Commande #${c['id']} · ${c['produit'] ?? ''}",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text("${c['quantite'] ?? ''} pièce(s)"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _choisir(c),
              ),
            )),
      ],
    );
  }

  Widget _message(IconData icone, String texte, Color couleur) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icone, size: 48, color: couleur),
          const SizedBox(height: 12),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.couleurTexte(context)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _charger,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Réessayer"),
          ),
        ],
      ),
    );
  }

  Widget _carteQr(CodeRetraitDonnees code) {
    final couleurEtat = code.bloque ? _rouge : AppTheme.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x0C2C241E), blurRadius: 20, offset: Offset(0, 6))],
        border: Border.all(color: AppTheme.couleurBordure(context)),
      ),
      child: Column(
        children: [
          // Statut Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: couleurEtat.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(code.bloque ? Icons.block : Icons.check_circle, color: couleurEtat, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    code.bloque
                        ? "Code bloqué : contactez le support ou l'agent"
                        : "Colis disponible au point de retrait",
                    style: TextStyle(color: couleurEtat, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Vrai QR code : strictement noir sur blanc (norme de scannabilité maximale)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black12, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: QrImageView(
              data: code.qrToken,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              semanticsLabel: 'Code de retrait QR de la commande ${code.commandeId}',
            ),
          ),

          const SizedBox(height: 16),
          Text(
            "Commande #${code.commandeId}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.couleurTexte(context)),
          ),
          if (code.expiration.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "Valable jusqu'au ${_date(code.expiration)}",
              style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context)),
            ),
          ],

          const SizedBox(height: 16),

          // Code court de secours à 8 chiffres (téléphone déchargé / caméra indisponible)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.couleurSurfaceDouce(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.couleurBordure(context)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pin_outlined, size: 16, color: AppTheme.couleurAccent(context)),
                    const SizedBox(width: 6),
                    Text(
                      "Code court de secours (8 chiffres)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.couleurTexteAttenue(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  (code.codeCourt != null && code.codeCourt!.isNotEmpty && code.codeCourt != "********")
                      ? code.codeCourt!
                      : "Reçu par SMS",
                  style: TextStyle(
                    fontFamily: AppTheme.policeTitre,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: AppTheme.couleurTexte(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "À présenter à l'agent si votre écran est fissuré ou déchargé",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.couleurTexteAttenue(context)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bouton Générer un nouveau code
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _actionEnCours ? null : _demanderRegeneration,
              icon: _actionEnCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.autorenew_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text("Générer un nouveau code"),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.couleurAccent(context),
                side: BorderSide(color: AppTheme.couleurAccent(context).withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteLieu() {
    final nomAffiche = _pointRetrait.split('—').first.trim();
    final adresseAffichee = _pointRetrait.contains('—') ? _pointRetrait.split('—').last.trim() : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.couleurBordure(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.place_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomAffiche,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context)),
                    ),
                    if (adresseAffichee != null)
                      Text(
                        adresseAffichee,
                        style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Marchandise : $_quantite x $_nomProduit",
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.couleurTexte(context)),
          ),
          if (_commande?['pointRetrait'] is Map) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final point = _commande!['pointRetrait'] as Map;
                  afficherItineraireDepot(
                    context,
                    nomDepot: point['nom']?.toString() ?? widget.pointRetrait,
                    adresse: point['adresse']?.toString(),
                    lienGoogleMaps: point['lienGoogleMap']?.toString(),
                  );
                },
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("Itinéraire vers le dépôt"),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _date(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à "
          "${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return iso;
    }
  }
}
