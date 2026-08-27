import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A bookable treatment.
///
/// The catalogue is fixed for this release, so services live in code rather
/// than in storage. Only the stable [id] is persisted — the display name is
/// resolved from the active language at render time.
@immutable
class SalonService {
  const SalonService({
    required this.id,
    required this.priceLabel,
    required this.icon,
    required this.tint,
  });

  final String id;

  /// Pre-formatted price, e.g. "1.000 TL". Written the same way in both
  /// languages, so it is not part of the string catalogue.
  final String priceLabel;

  final IconData icon;

  /// Background wash for the service thumbnail.
  final Color tint;

  /// The full catalogue, in the order shown on the selection screen.
  static const List<SalonService> catalogue = [
    SalonService(
      id: 'classic_manicure',
      priceLabel: '1.000 TL',
      icon: Icons.spa_outlined,
      tint: Color(0xFFF4EBFF),
    ),
    SalonService(
      id: 'gel_manicure',
      priceLabel: '1.000 TL',
      icon: Icons.auto_awesome_outlined,
      tint: Color(0xFFFFEFF4),
    ),
    SalonService(
      id: 'nail_art_design',
      priceLabel: '1.000 TL',
      icon: Icons.brush_outlined,
      tint: Color(0xFFEFF0FF),
    ),
    SalonService(
      id: 'pedicure',
      priceLabel: '1.000 TL',
      icon: Icons.water_drop_outlined,
      tint: Color(0xFFFDF0FF),
    ),
  ];

  /// The treatment's name in the active language.
  String name(AppLocalizations l10n) {
    switch (id) {
      case 'classic_manicure':
        return l10n.serviceClassicManicure;
      case 'gel_manicure':
        return l10n.serviceGelManicure;
      case 'nail_art_design':
        return l10n.serviceNailArtDesign;
      case 'pedicure':
        return l10n.servicePedicure;
      default:
        return id;
    }
  }

  /// Looks a service up by id; returns null for unknown or skipped services.
  static SalonService? byId(String? id) {
    if (id == null) return null;
    for (final service in catalogue) {
      if (service.id == id) return service;
    }
    return null;
  }
}
