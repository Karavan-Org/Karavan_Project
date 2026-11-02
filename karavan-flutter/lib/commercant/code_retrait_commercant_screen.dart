import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api/api_exception.dart';
import '../services/logistique_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/itineraire_depot.dart';

/// Écran du Code de Retrait sécurisé pour le Commerçant (RG-53, RG-71)
/// Affiche le vrai QR code de la commande (jeton généré par le backend) à présenter au point de retrait ;
/// le PIN à 4 chiffres, lui, n'est envoyé que par SMS (le backend n'en garde que l'empreinte).
/// Sans numéro de commande, l'écran cherche lui-même les commandes prêtes à être retirées.
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
  String? _erreur;
  List<Map<String, dynamic>> _aRetirer = [];
  Map<String, dynamic>? _commande;
  CodeRetraitDonnees? _code;

  @override
  void initState() {
    super.initState();
    _charger();
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
          "Code de Retrait Sécurisé",
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
            onPressed: _chargement ? null : _charger,
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
                        "Vos fonds restent protégés jusqu'à votre retrait.",
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
        "Aucune commande n'est encore prête à être retirée. Votre code apparaîtra ici dès que votre colis sera "
        "disponible au point de retrait (vous recevrez aussi le PIN par SMS).",
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Icon(icone, size: 48, color: couleur),
          const SizedBox(height: 12),
          Text(texte, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.4)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x0C2C241E), blurRadius: 20, offset: Offset(0, 6))],
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
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
                        ? "Code bloqué : demandez-en un nouveau au guichet"
                        : "Colis disponible au point de retrait",
                    style: TextStyle(color: couleurEtat, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Vrai QR code : le jeton est scanné au point de retrait (POST /api/retraits/valider)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.bordureForte, width: 2),
            ),
            child: QrImageView(
              data: code.qrToken,
              size: 220,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.primaryDark),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppTheme.primaryDark,
              ),
              semanticsLabel: 'QR code de retrait de la commande ${code.commandeId}',
            ),
          ),

          const SizedBox(height: 16),
          Text(
            "Commande #${code.commandeId}",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.couleurTexte(context)),
          ),
          if (code.expiration.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "Valable jusqu'au ${_date(code.expiration)}",
              style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context)),
            ),
          ],

          const SizedBox(height: 20),
          Divider(color: AppTheme.couleurBordure(context)),
          const SizedBox(height: 16),

          // Consigne PIN (RG-71) : le PIN n'est connu que par SMS
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.couleurSurfaceDouce(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.sms_outlined, color: AppTheme.couleurAccent(context), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Faites scanner ce QR code au guichet. Sans scanner, donnez le n° de commande "
                    "#${code.commandeId} et le code PIN reçu par SMS "
                    "(${code.tentativesRestantes} essai(s) restant(s)).",
                    style: TextStyle(fontSize: 12, color: AppTheme.couleurTexte(context), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Text(
            "Code perdu ou bloqué ? Le guichet peut vous envoyer un nouveau code par SMS.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: AppTheme.couleurTexteAttenue(context)),
              const SizedBox(width: 5),
              Text(
                "À montrer uniquement au guichet de retrait",
                style: TextStyle(fontSize: 11.5, color: AppTheme.couleurTexteAttenue(context), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (_aRetirer.length > 1) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _code = null;
                _commande = null;
              }),
              child: Text("Voir mes ${_aRetirer.length} commandes à retirer"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _carteLieu() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x082C241E), blurRadius: 15, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Lieu de retrait",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.couleurTexte(context)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: AppTheme.ocreProfond, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_pointRetrait, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
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
                label: const Text("Voir l'itinéraire vers le dépôt"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.bissap,
                  side: const BorderSide(color: Color(0x4DAC7F5E)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: AppTheme.bordure),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Article", style: TextStyle(fontSize: 12, color: AppTheme.couleurTexteAttenue(context))),
              Text("$_quantite unité(s)", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_nomProduit, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }

  static String _date(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String deux(int n) => n.toString().padLeft(2, '0');
    return "${deux(d.day)}/${deux(d.month)}/${d.year} à ${deux(d.hour)}:${deux(d.minute)}";
  }
}
