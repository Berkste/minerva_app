import 'package:flutter/foundation.dart';

import '../models/slot.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';

/// What a day looks like on the calendar, before anyone taps it.
enum DayAvailability {
  /// Bookable, with at least one hour free.
  open,

  /// Every hour is taken. Tappable but pointless, so the grid says so.
  full,

  /// A Sunday, or a day the salon declared shut.
  closed,

  /// Before today. Nothing to say about it.
  past,
}

/// Which days and hours are free, for the month and the day being looked at.
///
/// This is always a live question — it includes other people's bookings, so a
/// cached answer would be wrong the moment someone else books. When it cannot
/// be answered, the screens say so rather than pretending everything is free;
/// the database still has the final say at confirm time either way.
class AvailabilityProvider extends ChangeNotifier {
  AvailabilityProvider(this._repository);

  final BookingRepository _repository;

  // --- the day being looked at ---------------------------------------------

  DateTime? _date;
  Set<Slot> _bookedSlots = {};
  bool _isLoading = false;
  BookingException? _error;

  // --- the month on screen -------------------------------------------------

  DateTime? _month;
  Set<Slot> _monthSlots = {};
  Set<DateTime> _closedDays = {};
  bool _isLoadingMonth = false;
  BookingException? _monthError;

  Set<Slot> get bookedSlots => Set.unmodifiable(_bookedSlots);
  bool get isLoading => _isLoading;
  BookingException? get error => _error;

  bool get isLoadingMonth => _isLoadingMonth;
  BookingException? get monthError => _monthError;

  /// True when availability could not be fetched, so the grid is showing
  /// unverified slots.
  bool get isUnverified => _error != null;

  /// True when the month could not be fetched, so the calendar cannot mark
  /// full or closed days. It still lets the customer pick one — the rules are
  /// enforced at confirm time regardless, and a calendar that refuses to work
  /// offline is worse than one that cannot grey things out.
  bool get isMonthUnverified => _monthError != null;

  bool isTaken(Slot slot) => _bookedSlots.contains(slot);

  /// How [day] should be drawn on the month grid.
  ///
  /// Falls back to [DayAvailability.open] when the month has not loaded: an
  /// unmarked day the database later refuses is a better outcome than a
  /// calendar of greyed-out days because the network hiccuped.
  DayAvailability availabilityOf(DateTime day, {DateTime? today}) {
    final d = _dayOf(day);
    final from = _dayOf(today ?? DateTime.now());

    if (d.isBefore(from)) return DayAvailability.past;
    if (_closedDays.contains(d)) return DayAvailability.closed;

    // Sunday even before the month loads — it is a standing rule, not data.
    if (d.weekday == DateTime.sunday) return DayAvailability.closed;

    if (_month != null && _isFull(d)) return DayAvailability.full;

    return DayAvailability.open;
  }

  bool _isFull(DateTime day) =>
      Slot.salonHours.every((hour) => _monthSlots.contains(Slot(day, hour)));

  /// Loads availability for [date]. Repeated calls for the same day are
  /// ignored unless [force] is set.
  Future<void> loadFor(DateTime date, {bool force = false}) async {
    final normalised = _dayOf(date);
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

  /// Loads the whole month the calendar is showing: which slots are taken, and
  /// which days the salon is shut.
  ///
  /// One request per month rather than one per day — both functions take a
  /// range, and a customer paging through months should not fire thirty calls
  /// to find out that none of those days are free.
  Future<void> loadMonth(DateTime month, {bool force = false}) async {
    final first = DateTime(month.year, month.month, 1);
    if (!force && _month == first && !_isLoadingMonth && _monthError == null) {
      return;
    }

    // Day 0 of the next month is the last day of this one.
    final last = DateTime(month.year, month.month + 1, 0);

    _month = first;
    _isLoadingMonth = true;
    _monthError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.fetchBookedSlots(first, last),
        _repository.fetchClosedDays(first, last),
      ]);

      _monthSlots = results[0] as Set<Slot>;
      _closedDays = (results[1] as Set<DateTime>).map(_dayOf).toSet();
      _monthError = null;
    } on BookingException catch (failure) {
      _monthSlots = {};
      _closedDays = {};
      _monthError = failure;
    }

    _isLoadingMonth = false;
    notifyListeners();
  }

  /// Marks a slot taken locally, so the grid updates the instant a booking
  /// loses the race — without waiting for a round trip.
  void markTaken(Slot slot) {
    if (_bookedSlots.contains(slot) && _monthSlots.contains(slot)) return;
    _bookedSlots = {..._bookedSlots, slot};
    _monthSlots = {..._monthSlots, slot};
    notifyListeners();
  }

  /// Releases a slot locally, after a cancellation. Same reasoning as
  /// [markTaken]: the screen should not wait on a refetch to look right.
  void markFree(Slot slot) {
    if (!_bookedSlots.contains(slot) && !_monthSlots.contains(slot)) return;
    _bookedSlots = {..._bookedSlots}..remove(slot);
    _monthSlots = {..._monthSlots}..remove(slot);
    notifyListeners();
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}
