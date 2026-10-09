import 'package:flutter/material.dart';
import '../services/api/api_exception.dart';
import '../services/auth_service.dart';
import '../services/groupe_api_service.dart';
import '../services/lien_groupe.dart';
import '../theme/app_theme.dart';
import 'fiche_campagne_screen.dart';

/// Ouvre un groupe d'achat reçu par lien d'invitation (ou code saisi) : charge le groupe puis affiche sa fiche.
/// Sans session commerçant, le groupe est mis de côté et s'ouvrira juste après la connexion.
class OuvrirGroupeScreen extends StatefulWidget {
  final int groupeId;

  const OuvrirGroupeScreen({super.key, required this.groupeId});

  /// Demande au commerçant un lien ou un code de groupe, puis l'ouvre
  static Future<void> saisirLien(BuildContext context) async {
    final controleur = TextEditingController();
    final texte = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Rejoindre via un lien"),
        content: TextField(
          controller: controleur,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Lien ou code du groupe",
            hintText: "https://dogo.ml/groupe/12 ou DOGO-12",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controleur.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text("Ouvrir"),
          ),
        ],
      ),
    );
    controleur.dispose();
    if (texte == null || !context.mounted) return;
    final id = LienGroupe.extraireId(texte);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lien ou code de groupe non reconnu")),
      );
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OuvrirGroupeScreen(groupeId: id)));
  }

  @override
  State<OuvrirGroupeScreen> createState() => _OuvrirGroupeScreenState();
}

class _OuvrirGroupeScreenState extends State<OuvrirGroupeScreen> {
  String? _message;

  @override
  void initState() {
    super.initState();
    _ouvrir();
  }

  Future<void> _ouvrir() async {
    final profil = AuthService.instance.profilActuel;
    if (!AuthService.instance.estConnecte || profil?.type != 'COMMERCANT') {
      LienGroupe.enAttente = widget.groupeId;
      setState(() => _message =
          "Connectez-vous avec votre compte commerçant : le groupe n° ${widget.groupeId} s'ouvrira automatiquement.");
      return;
    }
    try {
      final g = await GroupeApiService.instance.detail(widget.groupeId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FicheCampagneScreen(
            id: g.id,
            titre: g.titre,
            sousTitre: g.sousTitre,
            imagePath: g.imagePath,
            prixGroupe: g.prixGroupe,
            prixPublic: g.prixPublic,
            quantiteActuelle: g.quantiteActuelle,
            quantiteObjectif: g.quantiteObjectif,
            categorie: g.categorie,
            paysOrigine: g.paysOrigine,
            courtierNom: g.courtierNom,
            tempsRestant: g.tempsRestant,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final introuvable = e is ApiException && e.statusCode == 404;
      setState(() => _message = introuvable
          ? "Ce groupe n'est pas encore publié ou n'existe plus. Réessayez un peu plus tard."
          : (e is ApiException ? e.messageComplet : "Ouverture impossible : $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text("Groupe ${LienGroupe.code(widget.groupeId)}",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _message == null
              ? const CircularProgressIndicator(color: AppTheme.primary)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded, size: 52, color: AppTheme.primary),
                    const SizedBox(height: 14),
                    Text(_message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 18),
                    TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text("Fermer")),
                  ],
                ),
        ),
      ),
    );
  }
}
