import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api/api_client.dart';
import '../theme/app_theme.dart';

/// Coordonnées du support, servies par le backend (/api/public/contact, configurées par KARAVAN_SUPPORT_*).
class ContactPlateforme {
  final String telephone;
  final String whatsapp;
  final String email;
  final String adresse;
  final String horaires;

  const ContactPlateforme({
    this.telephone = '',
    this.whatsapp = '',
    this.email = '',
    this.adresse = '',
    this.horaires = '',
  });

  factory ContactPlateforme.fromJson(Map<String, dynamic> j) => ContactPlateforme(
        telephone: j['telephone']?.toString() ?? '',
        whatsapp: j['whatsapp']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        adresse: j['adresse']?.toString() ?? '',
        horaires: j['horaires']?.toString() ?? '',
      );

  bool get estVide => telephone.isEmpty && whatsapp.isEmpty && email.isEmpty;

  static ContactPlateforme? _cache;

  /// Lu une fois par session (les coordonnées changent rarement) ; une erreur n'est pas mise en cache
  static Future<ContactPlateforme> charger({bool forcer = false}) async {
    if (_cache != null && !forcer) return _cache!;
    final rep = await ApiClient.instance.get('/api/public/contact');
    return _cache = ContactPlateforme.fromJson(Map<String, dynamic>.from(rep as Map));
  }
}

/// Carte de contact du support : WhatsApp, appel et e-mail ouvrent réellement l'application concernée.
/// Un canal non configuré côté serveur n'apparaît pas ; aucun numéro n'est écrit dans l'application.
class CarteSupportPlateforme extends StatefulWidget {
  /// Message pré-rempli de la discussion WhatsApp (contexte de l'utilisateur)
  final String messageWhatsapp;

  const CarteSupportPlateforme({super.key, this.messageWhatsapp = "Bonjour, j'ai besoin d'aide sur Karavan."});

  @override
  State<CarteSupportPlateforme> createState() => _CarteSupportPlateformeState();
}

class _CarteSupportPlateformeState extends State<CarteSupportPlateforme> {
  ContactPlateforme? _contact;
  bool _erreur = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger({bool forcer = false}) async {
    try {
      final c = await ContactPlateforme.charger(forcer: forcer);
      if (mounted) {
        setState(() {
          _contact = c;
          _erreur = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _erreur = true);
    }
  }

  Future<void> _ouvrir(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir l'application correspondante sur cet appareil.")));
    }
  }

  static String _chiffres(String numero) => numero.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Widget build(BuildContext context) {
    final c = _contact;
    if (_erreur) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_rounded, color: AppTheme.danger),
          title: const Text("Coordonnées du support indisponibles"),
          trailing: TextButton(onPressed: () => _charger(forcer: true), child: const Text("Réessayer")),
        ),
      );
    }
    if (c == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
    }
    if (c.estVide) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.support_agent_rounded),
          title: const Text("Support en cours de mise en place"),
          subtitle: const Text("Les coordonnées de l'équipe Karavan apparaîtront ici dès qu'elles seront publiées."),
          trailing: IconButton(
            tooltip: "Actualiser",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _charger(forcer: true),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.support_agent_rounded, size: 30),
          title: Text("Équipe Karavan", style: AppTheme.styleTitreMoyen(context)),
          subtitle: c.horaires.isNotEmpty ? Text(c.horaires) : null,
        ),
        if (c.whatsapp.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            title: const Text("Discuter sur WhatsApp"),
            subtitle: Text(c.whatsapp),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _ouvrir(Uri.parse(
                "https://wa.me/${_chiffres(c.whatsapp)}?text=${Uri.encodeComponent(widget.messageWhatsapp)}")),
          ),
        if (c.telephone.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.call_rounded),
            title: const Text("Appeler"),
            subtitle: Text(c.telephone),
            onTap: () => _ouvrir(Uri(scheme: 'tel', path: c.telephone.replaceAll(' ', ''))),
          ),
        if (c.email.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text("Écrire un e-mail"),
            subtitle: Text(c.email),
            onTap: () => _ouvrir(Uri(scheme: 'mailto', path: c.email, query: 'subject=Support Karavan')),
          ),
        if (c.adresse.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text("Adresse"),
            subtitle: Text(c.adresse),
          ),
      ]),
    );
  }
}
