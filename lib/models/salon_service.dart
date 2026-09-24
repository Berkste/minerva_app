import 'package:flutter/material.dart';

/// Whether a service is something a customer books, or something the salon
/// adds to a booking afterwards.
enum ServiceKind {
  /// A treatment. The customer picks one when booking.
  main,

  /// An add-on. Which ones apply is decided at the chair, so only staff record
  /// them — and two of them are priced as a range, which is the whole reason
  /// an appointment stores what was charged rather than deriving it.
  extra;

  static ServiceKind fromName(String? value) =>
      value == 'extra' ? extra : main;
}

/// A treatment or add-on, as the salon currently offers it.
///
/// This used to be a constant list in Dart with a pre-formatted price string.
/// It is a database table now, because staff have to be able to change prices
/// and retire treatments without anyone rebuilding the app.
@immutable
class SalonService {
  const SalonService({
    required this.id,
    required this.kind,
    required this.nameTr,
    required this.nameEn,
    required this.priceMin,
    this.priceMax,
    this.descriptionTr,
    this.descriptionEn,
    this.currency = 'TRY',
    this.sortOrder = 0,
  });

  final String id;
  final ServiceKind kind;

  final String nameTr;
  final String nameEn;
  final String? descriptionTr;
  final String? descriptionEn;

  /// The price, or the bottom of the range when [priceMax] is set.
  final num priceMin;

  /// Null for a fixed price. Set only for the open-ended add-ons.
  final num? priceMax;

  final String currency;
  final int sortOrder;

  bool get isRanged => priceMax != null && priceMax != priceMin;

  String name(String languageCode) => languageCode == 'en' ? nameEn : nameTr;

  String? description(String languageCode) =>
      languageCode == 'en' ? descriptionEn : descriptionTr;

  /// "850 TL", or "20 – 300 TL" where the salon charges by the work done.
  String get priceLabel {
    final suffix = currency == 'TRY' ? 'TL' : currency;
    if (isRanged) {
      return '${_money(priceMin)} – ${_money(priceMax!)} $suffix';
    }
    return '${_money(priceMin)} $suffix';
  }

  /// The icon shown on the selection card.
  ///
  /// Presentation stays in the app: the catalogue is the salon's to edit, and
  /// asking them to pick icon names in a form would be a worse job than
  /// choosing a sensible default here. Known treatments get a considered icon;
  /// anything staff add later still renders.
  IconData get icon => _icons[id] ?? _fallbackIcon;

  /// Background wash behind the icon. Chosen per service where we know it, and
  /// derived from the id otherwise so a new service is at least stable rather
  /// than changing colour between builds.
  Color get tint => _tints[id] ?? _palette[id.hashCode.abs() % _palette.length];

  factory SalonService.fromRow(Map<String, dynamic> row) => SalonService(
        id: row['id'] as String,
        kind: ServiceKind.fromName(row['kind'] as String?),
        nameTr: row['name_tr'] as String? ?? '',
        nameEn: row['name_en'] as String? ?? '',
        descriptionTr: row['description_tr'] as String?,
        descriptionEn: row['description_en'] as String?,
        priceMin: (row['price_min'] as num?) ?? 0,
        priceMax: row['price_max'] as num?,
        currency: row['currency'] as String? ?? 'TRY',
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name_tr': nameTr,
        'name_en': nameEn,
        'description_tr': descriptionTr,
        'description_en': descriptionEn,
        'price_min': priceMin,
        'price_max': priceMax,
        'currency': currency,
        'sort_order': sortOrder,
      };

  factory SalonService.fromJson(Map<String, dynamic> json) =>
      SalonService.fromRow(json);

  @override
  bool operator ==(Object other) => other is SalonService && other.id == id;

  @override
  int get hashCode => id.hashCode;

  // --- presentation ----------------------------------------------------

  static const IconData _fallbackIcon = Icons.spa_outlined;

  static const Map<String, IconData> _icons = {
    'protez_tirnak': Icons.auto_awesome_outlined,
    'protez_tirnak_bakim': Icons.autorenew_outlined,
    'duz_kalici_oje': Icons.brush_outlined,
    'jel_destekli_kalici_oje': Icons.opacity_outlined,
    'ayak_kalici_oje': Icons.water_drop_outlined,
    'medikal_manikur': Icons.spa_outlined,
    'medikal_pedikur': Icons.self_improvement_outlined,
    'sablon_sistem_protez': Icons.dashboard_customize_outlined,
    'nail_art': Icons.palette_outlined,
    'cat_eye': Icons.visibility_outlined,
    'french_ombre': Icons.gradient_outlined,
    'inci_krom_tozu': Icons.blur_on_outlined,
    'charm_tas': Icons.diamond_outlined,
    'tek_tirnak_protez': Icons.back_hand_outlined,
    'tirnak_cikarma': Icons.cleaning_services_outlined,
  };

  static const List<Color> _palette = [
    Color(0xFFF4EBFF),
    Color(0xFFFFEFF4),
    Color(0xFFEFF0FF),
    Color(0xFFFDF0FF),
  ];

  static const Map<String, Color> _tints = {
    'protez_tirnak': Color(0xFFF4EBFF),
    'protez_tirnak_bakim': Color(0xFFFFEFF4),
    'duz_kalici_oje': Color(0xFFEFF0FF),
    'jel_destekli_kalici_oje': Color(0xFFFDF0FF),
    'ayak_kalici_oje': Color(0xFFF4EBFF),
    'medikal_manikur': Color(0xFFFFEFF4),
    'medikal_pedikur': Color(0xFFEFF0FF),
  };

  /// Turkish thousands separator, no decimals — prices are whole lira.
  static String _money(num value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// One line on an appointment: what was done, and what it cost.
///
/// The amount is a copy taken when the line was added, so changing the
/// catalogue never rewrites what a past visit cost.
@immutable
class AppointmentService {
  const AppointmentService({
    required this.serviceId,
    required this.kind,
    required this.amount,
    this.id,
    this.service,
  });

  /// Server-generated. Null for a line built locally — a fake, a cache — which
  /// is also why removing one is only offered where the id came from the
  /// database.
  final String? id;

  final String serviceId;
  final ServiceKind kind;
  final num amount;

  /// The catalogue entry, when it was loaded alongside. Null when only the
  /// line itself was fetched.
  final SalonService? service;

  factory AppointmentService.fromRow(Map<String, dynamic> row) {
    final joined = row['services'];
    return AppointmentService(
      id: row['id'] as String?,
      serviceId: row['service_id'] as String,
      kind: ServiceKind.fromName(row['kind'] as String?),
      amount: (row['amount'] as num?) ?? 0,
      service: joined is Map<String, dynamic>
          ? SalonService.fromRow(joined)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'service_id': serviceId,
        'kind': kind.name,
        'amount': amount,
        if (service != null) 'services': service!.toJson(),
      };

  factory AppointmentService.fromJson(Map<String, dynamic> json) =>
      AppointmentService.fromRow(json);
}

/// Reading a service's name needs the active language, and every screen that
/// shows one already has a [BuildContext]. This saves each of them from
/// spelling out the locale lookup.
extension SalonServiceText on SalonService {
  String localisedName(BuildContext context) =>
      name(Localizations.localeOf(context).languageCode);

  String? localisedDescription(BuildContext context) =>
      description(Localizations.localeOf(context).languageCode);
}
