import 'package:flutter/material.dart';


/// A bookable treatment.
///
/// The catalogue is fixed for this release, so services live in code rather
/// than in storage. Each one carries its own tint, which stands in for the
/// photo thumbnail in the design.
@immutable
class SalonService {
  const SalonService({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.icon,
    required this.tint,
  });

  final String id;
  final String name;

  /// Pre-formatted price, e.g. "1.000 TL".
  final String priceLabel;

  final IconData icon;

  /// Background wash for the service thumbnail.
  final Color tint;

  /// The full catalogue, in the order shown on the selection screen.
  static const List<SalonService> catalogue = [
    SalonService(
      id: 'classic_manicure',
      name: 'Classic Manicure',
      priceLabel: '1.000 TL',
      icon: Icons.spa_outlined,
      tint: Color(0xFFF4EBFF),
    ),
    SalonService(
      id: 'gel_manicure',
      name: 'Gel Manicure',
      priceLabel: '1.000 TL',
      icon: Icons.auto_awesome_outlined,
      tint: Color(0xFFFFEFF4),
    ),
    SalonService(
      id: 'nail_art_design',
      name: 'Nail Art Design',
      priceLabel: '1.000 TL',
      icon: Icons.brush_outlined,
      tint: Color(0xFFEFF0FF),
    ),
    SalonService(
      id: 'pedicure',
      name: 'Pedicure',
      priceLabel: '1.000 TL',
      icon: Icons.water_drop_outlined,
      tint: Color(0xFFFDF0FF),
    ),
  ];

  /// Looks a service up by id; returns null for unknown or skipped services.
  static SalonService? byId(String? id) {
    if (id == null) return null;
    for (final service in catalogue) {
      if (service.id == id) return service;
    }
    return null;
  }

  /// Display name for a possibly-skipped service.
  static String nameFor(String? id) => byId(id)?.name ?? 'Not selected';
}

