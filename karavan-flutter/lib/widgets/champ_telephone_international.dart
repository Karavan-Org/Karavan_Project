import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import '../theme/app_theme.dart';

/// Champ de saisie téléphonique international Karavan avec sélection d'indicatif pays
/// basé sur `intl_phone_field: ^3.2.0`, adapté à la charte graphique et au mode sombre.
class ChampTelephoneInternational extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onNumeroCompletChange;
  final ValueChanged<Country>? onCountryChanged;
  final String initialCountryCode;
  final String label;
  final String hintText;
  final Color? borderColor;
  final Color? accentColor;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onSubmitted;

  const ChampTelephoneInternational({
    super.key,
    required this.controller,
    this.onNumeroCompletChange,
    this.onCountryChanged,
    this.initialCountryCode = 'ML',
    this.label = "Numéro de téléphone",
    this.hintText = "70 00 00 00",
    this.borderColor,
    this.accentColor,
    this.enabled = true,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  State<ChampTelephoneInternational> createState() =>
      _ChampTelephoneInternationalState();
}

class _ChampTelephoneInternationalState
    extends State<ChampTelephoneInternational> {
  late String _dialCode;
  late String _countryCode;

  @override
  void initState() {
    super.initState();
    _countryCode = widget.initialCountryCode;
    final country = countries.firstWhere(
      (c) => c.code == _countryCode,
      orElse: () => countries.firstWhere((c) => c.code == 'ML'),
    );
    _dialCode = country.dialCode;

    // Si le controller contient déjà un indicatif international, le nettoyer
    _normaliserValeurInitiale();

    widget.controller.addListener(_notifierNumeroComplet);
  }

  void _normaliserValeurInitiale() {
    final texte = widget.controller.text.trim();
    if (texte.isEmpty) return;

    if (texte.startsWith('+$_dialCode')) {
      widget.controller.text = texte.substring(_dialCode.length + 1).trim();
    } else if (texte.startsWith(_dialCode) && texte.length > _dialCode.length + 4) {
      widget.controller.text = texte.substring(_dialCode.length).trim();
    }
  }

  void _notifierNumeroComplet() {
    final local = widget.controller.text.replaceAll(RegExp(r'\s+'), '');
    if (local.isEmpty) {
      widget.onNumeroCompletChange?.call('');
      return;
    }
    final complet = local.startsWith('+') ? local : '+$_dialCode$local';
    widget.onNumeroCompletChange?.call(complet);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_notifierNumeroComplet);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couleurCarte = AppTheme.couleurCarte(context);
    final couleurBordure = widget.borderColor ?? AppTheme.couleurBordure(context);
    final couleurTexte = AppTheme.couleurTexte(context);
    final couleurAttenue = AppTheme.couleurTexteAttenue(context);
    final camelColor = widget.accentColor ?? AppTheme.bissap;
    final isDark = AppTheme.estSombre(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: couleurCarte,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: couleurBordure, width: 1.2),
        boxShadow: AppTheme.ombreDouce,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: camelColor.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.phone_outlined, color: camelColor, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: couleurAttenue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          IntlPhoneField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            initialCountryCode: widget.initialCountryCode,
            languageCode: 'fr',
            disableLengthCheck: true,
            showCountryFlag: true,
            showDropdownIcon: true,
            dropdownIconPosition: IconPosition.trailing,
            dropdownIcon: Icon(
              Icons.arrow_drop_down_rounded,
              color: camelColor,
              size: 22,
            ),
            flagsButtonMargin: const EdgeInsets.only(right: 8),
            flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 2),
            dropdownTextStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: couleurTexte,
            ),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: couleurTexte,
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: couleurAttenue,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
            pickerDialogStyle: PickerDialogStyle(
              backgroundColor: couleurCarte,
              countryNameStyle: TextStyle(
                color: couleurTexte,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              countryCodeStyle: TextStyle(
                color: camelColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              searchFieldCursorColor: camelColor,
              searchFieldPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              listTilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              searchFieldInputDecoration: InputDecoration(
                hintText: "Rechercher un pays ou un indicatif...",
                hintStyle: TextStyle(color: couleurAttenue, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: camelColor, size: 20),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: camelColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            onCountryChanged: (country) {
              setState(() {
                _countryCode = country.code;
                _dialCode = country.dialCode;
              });
              widget.onCountryChanged?.call(country);
              _notifierNumeroComplet();
            },
            onChanged: (phone) {
              widget.onNumeroCompletChange?.call(phone.completeNumber);
            },
          ),
        ],
      ),
    );
  }
}

