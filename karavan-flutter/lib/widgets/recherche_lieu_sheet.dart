import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/itineraire_service.dart';
import '../theme/app_theme.dart';

class RechercheLieuSheet extends StatefulWidget {
  final LatLng? aProximiteDe;

  const RechercheLieuSheet({super.key, this.aProximiteDe});

  @override
  State<RechercheLieuSheet> createState() => _RechercheLieuSheetState();
}

class _RechercheLieuSheetState extends State<RechercheLieuSheet> {
  final _controller = TextEditingController();
  List<ResultatLieu> _resultats = const [];
  bool _chargement = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onRechercheChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _resultats = const [];
        _chargement = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _chargement = true);
      final res = await ItineraireService.rechercherLieux(val,
          aProximiteDe: widget.aProximiteDe);
      if (!mounted) return;
      setState(() {
        _resultats = res;
        _chargement = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: bottomInset > 0 ? bottomInset + 16 : systemBottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.bordureForte,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Rechercher un lieu ou une adresse",
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.terre),
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDouce,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.bordureForte),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onRechercheChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppTheme.bissap),
                hintText: "Ex : Grand Marché, Hamdallaye, ACI 2000…",
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppTheme.textePale),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _chargement
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.bissap),
                        ),
                      )
                    : (_controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: AppTheme.textMuted),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _resultats = const []);
                            },
                          )
                        : null),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_resultats.isNotEmpty)
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _resultats.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppTheme.bordure),
                itemBuilder: (ctx, i) {
                  final lieu = _resultats[i];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: AppTheme.bordure, shape: BoxShape.circle),
                      child: const Icon(Icons.location_on_rounded,
                          color: AppTheme.bissap, size: 20),
                    ),
                    title: Text(lieu.nom,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      lieu.adresseComplete,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                    onTap: () => Navigator.of(context).pop(lieu),
                  );
                },
              ),
            )
          else if (_controller.text.trim().length >= 2 && !_chargement)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "Aucun lieu trouvé pour cette recherche.",
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
