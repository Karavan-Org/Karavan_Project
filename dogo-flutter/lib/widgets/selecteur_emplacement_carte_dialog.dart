import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// Données retournées après sélection d'un emplacement
class DonneesEmplacement {
  final String quartier;
  final double latitude;
  final double longitude;

  const DonneesEmplacement({
    required this.quartier,
    required this.latitude,
    required this.longitude,
  });
}

/// Boîte de dialogue moderne permettant de choisir un emplacement sur carte OpenStreetMap interactive
class SelecteurEmplacementCarteDialog extends StatefulWidget {
  final String titre;
  final String sousTitre;
  final double? latitudeInitiale;
  final double? longitudeInitiale;
  final String? quartierInitial;

  const SelecteurEmplacementCarteDialog({
    super.key,
    this.titre = "Choisir l'emplacement sur la carte",
    this.sousTitre = "Touchez la carte pour positionner votre repère",
    this.latitudeInitiale,
    this.longitudeInitiale,
    this.quartierInitial,
  });

  static Future<DonneesEmplacement?> ouvrir({
    required BuildContext context,
    String? titre,
    String? sousTitre,
    double? latitudeInitiale,
    double? longitudeInitiale,
    String? quartierInitial,
  }) {
    return showDialog<DonneesEmplacement>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          child: SelecteurEmplacementCarteDialog(
            titre: titre ?? "Choisir l'emplacement sur la carte",
            sousTitre: sousTitre ?? "Touchez la carte pour positionner votre repère",
            latitudeInitiale: latitudeInitiale,
            longitudeInitiale: longitudeInitiale,
            quartierInitial: quartierInitial,
          ),
        ),
      ),
    );
  }

  @override
  State<SelecteurEmplacementCarteDialog> createState() =>
      _SelecteurEmplacementCarteDialogState();
}

class _SelecteurEmplacementCarteDialogState
    extends State<SelecteurEmplacementCarteDialog> {
  static const LatLng _centreBamako = LatLng(12.6392, -8.0029);

  late final MapController _mapController;
  late final TextEditingController _quartierController;
  late LatLng _positionSelectionnee;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _quartierController = TextEditingController(
      text: widget.quartierInitial ?? "Bamako",
    );
    if (widget.latitudeInitiale != null && widget.longitudeInitiale != null) {
      _positionSelectionnee = LatLng(
        widget.latitudeInitiale!,
        widget.longitudeInitiale!,
      );
    } else {
      _positionSelectionnee = _centreBamako;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _quartierController.dispose();
    super.dispose();
  }

  void _recentrerSurBamako() {
    _mapController.move(_centreBamako, 14.0);
    setState(() {
      _positionSelectionnee = _centreBamako;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = AppTheme.estSombre(context);
    final fond = AppTheme.couleurCarte(context);
    final texte = AppTheme.couleurTexte(context);
    final bordure = AppTheme.couleurBordure(context);

    return Scaffold(
      backgroundColor: fond,
      appBar: AppBar(
        title: Text(
          widget.titre,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "Recentrer sur Bamako",
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _recentrerSurBamako,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau d'information et coordonnées courantes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: estSombre
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF7F5F0),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 20,
                  color: AppTheme.doreKaravan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.sousTitre,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: texte,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bissap.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.bissap.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    "${_positionSelectionnee.latitude.toStringAsFixed(4)}, ${_positionSelectionnee.longitude.toStringAsFixed(4)}",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.bissap,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Carte interactive OpenStreetMap
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _positionSelectionnee,
                    initialZoom: 14.0,
                    minZoom: 4.0,
                    maxZoom: 18.5,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _positionSelectionnee = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.karavan_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _positionSelectionnee,
                          width: 60,
                          height: 60,
                          alignment: Alignment.topCenter,
                          child: const _MarqueurPositionAnime(),
                        ),
                      ],
                    ),
                  ],
                ),

                // Boutons de zoom flottants
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Column(
                    children: [
                      _BoutonActionCarte(
                        icone: Icons.add_rounded,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            (currentZoom + 1).clamp(4.0, 18.5),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _BoutonActionCarte(
                        icone: Icons.remove_rounded,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            (currentZoom - 1).clamp(4.0, 18.5),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Saisie du nom de quartier et confirmation
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: fond,
              border: Border(top: BorderSide(color: bordure, width: 1.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _quartierController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.place_outlined, size: 20),
                    labelText: "Quartier / Marché / Adresse de repère",
                    hintText: "Ex : Grand Marché Dabanani, Halles de Bamako...",
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Annuler"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          "Confirmer cet emplacement",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.bissap,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final q = _quartierController.text.trim();
                          Navigator.pop(
                            context,
                            DonneesEmplacement(
                              quartier: q.isNotEmpty ? q : "Bamako",
                              latitude: _positionSelectionnee.latitude,
                              longitude: _positionSelectionnee.longitude,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marqueur stylisé avec épingle dorée et ombre portée
class _MarqueurPositionAnime extends StatelessWidget {
  const _MarqueurPositionAnime();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.bissap,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.storefront_rounded,
              color: AppTheme.doreKaravan,
              size: 20,
            ),
          ),
        ),
        Container(
          width: 3,
          height: 10,
          color: AppTheme.bissap,
        ),
        Container(
          width: 8,
          height: 4,
          decoration: const BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// Bouton rond compact pour les contrôles de zoom sur la carte
class _BoutonActionCarte extends StatelessWidget {
  final IconData icone;
  final VoidCallback onPressed;

  const _BoutonActionCarte({required this.icone, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icone, color: Colors.black87, size: 22),
        ),
      ),
    );
  }
}

/// Boîte de dialogue pour la saisie directe des coordonnées GPS (Latitude / Longitude / Quartier)
class SaisieCoordonneesDialog extends StatefulWidget {
  final String titre;
  final String? quartierInitial;
  final double? latitudeInitiale;
  final double? longitudeInitiale;

  const SaisieCoordonneesDialog({
    super.key,
    this.titre = "Coordonnées géographiques",
    this.quartierInitial,
    this.latitudeInitiale,
    this.longitudeInitiale,
  });

  static Future<DonneesEmplacement?> ouvrir({
    required BuildContext context,
    String? titre,
    String? quartierInitial,
    double? latitudeInitiale,
    double? longitudeInitiale,
  }) {
    return showDialog<DonneesEmplacement>(
      context: context,
      builder: (_) => SaisieCoordonneesDialog(
        titre: titre ?? "Coordonnées géographiques",
        quartierInitial: quartierInitial,
        latitudeInitiale: latitudeInitiale,
        longitudeInitiale: longitudeInitiale,
      ),
    );
  }

  @override
  State<SaisieCoordonneesDialog> createState() => _SaisieCoordonneesDialogState();
}

class _SaisieCoordonneesDialogState extends State<SaisieCoordonneesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quartierController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    _quartierController = TextEditingController(text: widget.quartierInitial ?? '');
    _latController = TextEditingController(
      text: widget.latitudeInitiale != null
          ? widget.latitudeInitiale!.toStringAsFixed(6)
          : '',
    );
    _lngController = TextEditingController(
      text: widget.longitudeInitiale != null
          ? widget.longitudeInitiale!.toStringAsFixed(6)
          : '',
    );
  }

  @override
  void dispose() {
    _quartierController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    final lat = double.tryParse(_latController.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lngController.text.trim().replaceAll(',', '.'));
    if (lat == null || lng == null) return;

    Navigator.pop(
      context,
      DonneesEmplacement(
        quartier: _quartierController.text.trim(),
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _quartierController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Quartier / Marché / Adresse",
                  hintText: "Ex : Grand Marché Dabanani",
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Veuillez renseigner le quartier"
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: "Latitude",
                  hintText: "Ex : 12.6392",
                  prefixIcon: Icon(Icons.navigation_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Latitude requise";
                  final d = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (d == null || d < -90 || d > 90) return "Latitude invalide (-90 à +90)";
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lngController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: "Longitude",
                  hintText: "Ex : -8.0029",
                  prefixIcon: Icon(Icons.explore_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Longitude requise";
                  final d = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (d == null || d < -180 || d > 180) return "Longitude invalide (-180 à +180)";
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.bissap,
            foregroundColor: Colors.white,
          ),
          onPressed: _valider,
          child: const Text("Enregistrer"),
        ),
      ],
    );
  }
}

