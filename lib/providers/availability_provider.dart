import 'package:flutter/foundation.dart';

import '../models/slot.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';

/// Which slots are already taken on the day being looked at.
///
/// This is always a live question — it includes other people's bookings, so a
/// cached answer would be wrong the moment someone else books. When it cannot
/// be answered, the time grid says so rather than pretending everything is
/// free; the database still has the final say at confirm time either way.
class AvailabilityProvider extends ChangeNotifier {
  AvailabilityProvider(this._repository);

  final BookingRepository _repository;

  DateTime? _date;
  Set<Slot> _bookedSlots = {};
  bool _isLoading = false;
  BookingException? _error;

  Set<Slot> get bookedSlots => Set.unmodifiable(_bookedSlots);
  bool get isLoading => _isLoading;
  BookingException? get error => _error;

  /// True when availability could not be fetched, so the grid is showing
  /// unverified slots.
  bool get isUnverified => _error != null;

  bool isTaken(Slot slot) => _bookedSlots.contains(slot);

  /// Loads availability for [date]. Repeated calls for the same day are
  /// ignored unless [force] is set.
  Future<void> loadFor(DateTime date, {bool force = false}) async {
    final normalised = DateTime(date.year, date.month, date.day);
    if (!force && _date == normalised && !_isLoading && _error == null) return;

    _date = normalised;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bookedSlots = await _repository.fetchBookedSlots(normalised, normalised);
      _error = null;
    } on BookingException catch (failure) {
      _bookedSlots = {};
      _error = failure;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Marks a slot taken locally, so the grid updates the instant a booking
  /// loses the race — without waiting for a round trip.
  void markTaken(Slot slot) {
    if (_bookedSlots.contains(slot)) return;
    _bookedSlots = {..._bookedSlots, slot};
    notifyListeners();
  }
}
