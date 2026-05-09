import 'package:flutter/material.dart';
import 'font_awesome_name_mapping.dart';

class FontAwesomeHelper {
  static const Map<String, IconData> _nodeSeekIconAliases = {
    'tea': Icons.local_cafe_rounded,
    'formula': Icons.functions_rounded,
    'receiver': Icons.settings_input_antenna_rounded,
    'dashboard-one': Icons.dashboard_outlined,
    'dollar': Icons.attach_money_rounded,
    'car': Icons.directions_car_rounded,
    'hold-interface': Icons.campaign_outlined,
    'oval-love-two': Icons.favorite_border_rounded,
    'terminal': Icons.terminal_rounded,
    'pic-one': Icons.image_outlined,
    'face-recognition': Icons.center_focus_weak_rounded,
    'open-one': Icons.lock_open_rounded,
    'texture': Icons.texture_rounded,
    'experiment': Icons.science_outlined,
  };

  static IconData? getIcon(String? name) {
    if (name == null) return null;
    final raw = name.trim().toLowerCase();
    if (raw.isEmpty) return null;

    // Try parse css-like class names first (fa-*, fas fa-*, far fa-*, fab fa-*)
    IconData? icon;
    if (raw.contains('fa-') || raw.contains('fa ')) {
      final normalized = raw
          .replaceAll('fa-solid', 'fas')
          .replaceAll('fa-regular', 'far')
          .replaceAll('fa-brands', 'fab')
          .replaceAll('fa-light', 'fal')
          .replaceAll('fa-thin', 'fat')
          .replaceAll('fa-duotone', 'fad');
      try {
        icon = getIconFromCss(normalized);
      } catch (_) {
        icon = null;
      }
      if (icon != null) return icon;
    }

    // Fallback to direct name mapping.
    final clean = raw
        .replaceAll('fa-', '')
        .replaceAll('fas-', '')
        .replaceAll('far-', '')
        .replaceAll('fab-', '')
        .replaceAll('fas ', '')
        .replaceAll('far ', '')
        .replaceAll('fab ', '')
        .replaceAll('fa ', '');

    final aliasIcon = _nodeSeekIconAliases[clean] ?? _nodeSeekIconAliases[raw];
    if (aliasIcon != null) return aliasIcon;

    for (final style in const ['solid', 'regular', 'brands']) {
      icon = faIconNameMapping['$style $clean'];
      if (icon != null) return icon;
    }

    return null;
  }
}
