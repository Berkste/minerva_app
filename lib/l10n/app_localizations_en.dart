// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Minerva Nail Art';

  @override
  String get dateFullPattern => 'EEEE, d MMMM yyyy';

  @override
  String get dateShortPattern => 'd MMM yyyy';

  @override
  String get monthYearPattern => 'MMMM yyyy';

  @override
  String get splashTagline => 'Beautiful nails,\nperfect time.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get navHome => 'Home';

  @override
  String get navAppointments => 'Appointments';

  @override
  String get navProfile => 'Profile';

  @override
  String get heroTitle => 'Your beauty,\nour passion.';

  @override
  String get heroSubtitle => 'Book your appointment\neasily and quickly.';

  @override
  String get newAppointment => 'New Appointment';

  @override
  String get myNextAppointment => 'My Next Appointment';

  @override
  String get seeAll => 'See all';

  @override
  String get noAppointmentYet => 'No appointment yet';

  @override
  String get noAppointmentYetHint =>
      'Tap \"New Appointment\" to book your visit.';

  @override
  String get ourServices => 'Our Services';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get selectedDate => 'Selected Date';

  @override
  String get pickADayAbove => 'Pick a day above';

  @override
  String get selectTime => 'Select Time';

  @override
  String appointmentDurationHint(int hours) {
    return 'Each appointment is $hours hours.';
  }

  @override
  String durationHours(int hours) {
    return '$hours hours';
  }

  @override
  String get slotBooked => 'Booked';

  @override
  String get continueLabel => 'Continue';

  @override
  String get yourDetails => 'Your Details';

  @override
  String get pleaseEnterYourInformation => 'Please enter your information';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get phoneHint => '(555) 555 55 55';

  @override
  String get detailsPrivacyNote =>
      'Your details stay on this device and are only used for this booking.';

  @override
  String get firstNameRequired => 'Please enter your first name.';

  @override
  String get lastNameRequired => 'Please enter your last name.';

  @override
  String get firstNameTooShort => 'That first name looks too short.';

  @override
  String get lastNameTooShort => 'That last name looks too short.';

  @override
  String get phoneRequired => 'Please enter your phone number.';

  @override
  String get phoneInvalid => 'Enter the number as (555) 555 55 55.';

  @override
  String get selectServiceOptional => 'Select Service (Optional)';

  @override
  String get chooseTheServiceYouWant => 'Choose the service you want';

  @override
  String get skipThisStep => 'Skip this step';

  @override
  String get serviceClassicManicure => 'Classic Manicure';

  @override
  String get serviceGelManicure => 'Gel Manicure';

  @override
  String get serviceNailArtDesign => 'Nail Art Design';

  @override
  String get servicePedicure => 'Pedicure';

  @override
  String get serviceNotSelected => 'Not selected';

  @override
  String get serviceNotSelectedOnCard => 'Service not selected';

  @override
  String get reviewAndConfirm => 'Review & Confirm';

  @override
  String get appointmentDetails => 'Appointment Details';

  @override
  String get labelDate => 'Date';

  @override
  String get labelTime => 'Time';

  @override
  String get labelService => 'Service';

  @override
  String get labelPrice => 'Price';

  @override
  String get labelDuration => 'Duration';

  @override
  String get yourInformation => 'Your Information';

  @override
  String get labelName => 'Name';

  @override
  String get labelPhone => 'Phone';

  @override
  String get reviewEditHint => 'Need a change? Tap back to edit any step.';

  @override
  String get confirmAppointment => 'Confirm Appointment';

  @override
  String get slotTakenMeanwhile =>
      'That slot was just booked. Please pick another time.';

  @override
  String get appointmentConfirmed => 'Appointment\nConfirmed!';

  @override
  String thankYouMessage(String name) {
    return 'Thank you, $name!\nWe look forward to seeing you.';
  }

  @override
  String get backToHome => 'Back to Home';

  @override
  String get myAppointments => 'My Appointments';

  @override
  String get sectionUpcoming => 'Upcoming';

  @override
  String get sectionPast => 'Past';

  @override
  String get upcomingAppointment => 'Upcoming Appointment';

  @override
  String get completedAppointment => 'Completed Appointment';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get addNewAppointment => 'Add New Appointment';

  @override
  String get noAppointmentsTitle => 'No appointments yet';

  @override
  String get noAppointmentsMessage =>
      'Your bookings will appear here once you schedule your first visit.';

  @override
  String get nothingComingUp => 'Nothing coming up — book your next visit.';

  @override
  String get cancelAppointment => 'Cancel appointment';

  @override
  String get cancelAppointmentTitle => 'Cancel appointment?';

  @override
  String cancelAppointmentBody(String date, String time) {
    return 'Your booking on $date at $time will be removed.';
  }

  @override
  String get keepIt => 'Keep it';

  @override
  String get cancelBooking => 'Cancel booking';

  @override
  String get profileTitle => 'Profile';

  @override
  String get guest => 'Guest';

  @override
  String get bookOnceToSaveDetails => 'Book once to save your details';

  @override
  String get statUpcoming => 'Upcoming';

  @override
  String get statCompleted => 'Completed';

  @override
  String get salon => 'Salon';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get openingHoursValue => '10:00 – 22:00, every day';

  @override
  String get appointmentLength => 'Appointment length';

  @override
  String appointmentLengthValue(int hours) {
    return 'Every booking lasts $hours hours';
  }

  @override
  String get yourData => 'Your data';

  @override
  String get yourDataValue => 'Stored on this device only';

  @override
  String version(String number) {
    return 'Version $number';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageTurkish => 'Turkish';

  @override
  String get languageEnglish => 'English';
}
