import 'package:flutter/foundation.dart';

import '../models/salon_service.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import 'appointment_provider.dart' show LoadState;

/// The salon's treatments, loaded once and shared.
///
/// The catalogue used to be a constant list in Dart. It is rows now, because
/// staff change prices and retire treatments without anyone rebuilding the
/// app — which means every screen that shows a treatment name has to resolve
/// it from somewhere. This is that somewhere.
///
/// It is small (a handful of rows) and rarely changes, so it is fetched once
/// and held. Nothing here writes; the admin app edits the table directly.
class CatalogueProvider extends ChangeNotifier {
  CatalogueProvider(this._repository);

  final BookingRepository _repository;

  List<SalonService> _treatments = const [];
  Map<String, SalonService> _byId = const {};

  LoadState _state = LoadState.loading;
  BookingException? _error;

  /// Bookable treatments, in the order the salon put them in.
  List<SalonService> get treatments => _treatments;

  LoadState get state => _state;
  BookingException? get error => _error;
  bool get isLoading => _state == LoadState.loading;
  bool get isEmpty => _treatments.isEmpty;

  /// The treatment behind an id, or null for an unknown or absent one.
  ///
  /// Returns null rather than throwing: a booking may name a treatment that
  /// has since been retired, and a missing name is a far better outcome than
  /// a screen that will not render.
  SalonService? byId(String? id) => id == null ? null : _byId[id];

  Future<void> load({bool force = false}) async {
    if (!force && _treatments.isNotEmpty) return;

    _state = LoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final loaded = await _repository.fetchTreatments();
      _treatments = loaded;
      _byId = {for (final service in loaded) service.id: service};
      _error = null;
      _state = LoadState.ready;
    } on BookingException catch (failure) {
      // Keep whatever was loaded before. A booking flow with a stale price
      // list is worth more than one that cannot show any treatment at all.
      _error = failure;
      _state = _treatments.isEmpty ? LoadState.failed : LoadState.ready;
    }

    notifyListeners();
  }
}
