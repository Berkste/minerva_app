import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Application name, shown as the task title.
  ///
  /// In tr, this message translates to:
  /// **'Minerva Nail Art'**
  String get appTitle;

  /// intl DateFormat pattern for a full date. Turkish convention puts the weekday last: 3 Eylül 2026 Perşembe.
  ///
  /// In tr, this message translates to:
  /// **'d MMMM yyyy EEEE'**
  String get dateFullPattern;

  /// intl DateFormat pattern for a compact date.
  ///
  /// In tr, this message translates to:
  /// **'d MMM yyyy'**
  String get dateShortPattern;

  /// intl DateFormat pattern for the calendar header.
  ///
  /// In tr, this message translates to:
  /// **'MMMM yyyy'**
  String get monthYearPattern;

  /// No description provided for @splashTagline.
  ///
  /// In tr, this message translates to:
  /// **'Güzel tırnaklar,\nmükemmel zaman.'**
  String get splashTagline;

  /// No description provided for @getStarted.
  ///
  /// In tr, this message translates to:
  /// **'Başlayalım'**
  String get getStarted;

  /// No description provided for @navHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get navHome;

  /// No description provided for @navAppointments.
  ///
  /// In tr, this message translates to:
  /// **'Randevular'**
  String get navAppointments;

  /// No description provided for @navProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @heroTitle.
  ///
  /// In tr, this message translates to:
  /// **'Güzelliğiniz,\nbizim tutkumuz.'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Randevunuzu kolay ve\nhızlı bir şekilde alın.'**
  String get heroSubtitle;

  /// No description provided for @newAppointment.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Randevu'**
  String get newAppointment;

  /// No description provided for @myNextAppointment.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki Randevum'**
  String get myNextAppointment;

  /// No description provided for @seeAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü gör'**
  String get seeAll;

  /// No description provided for @noAppointmentYet.
  ///
  /// In tr, this message translates to:
  /// **'Henüz randevunuz yok'**
  String get noAppointmentYet;

  /// No description provided for @noAppointmentYetHint.
  ///
  /// In tr, this message translates to:
  /// **'Randevu almak için \"Yeni Randevu\"ya dokunun.'**
  String get noAppointmentYetHint;

  /// No description provided for @ourServices.
  ///
  /// In tr, this message translates to:
  /// **'Hizmetlerimiz'**
  String get ourServices;

  /// No description provided for @calendarTitle.
  ///
  /// In tr, this message translates to:
  /// **'Takvim'**
  String get calendarTitle;

  /// No description provided for @selectedDate.
  ///
  /// In tr, this message translates to:
  /// **'Seçilen Tarih'**
  String get selectedDate;

  /// No description provided for @pickADayAbove.
  ///
  /// In tr, this message translates to:
  /// **'Yukarıdan bir gün seçin'**
  String get pickADayAbove;

  /// No description provided for @selectTime.
  ///
  /// In tr, this message translates to:
  /// **'Saat Seç'**
  String get selectTime;

  /// No description provided for @appointmentDurationHint.
  ///
  /// In tr, this message translates to:
  /// **'Her randevu {hours} saat sürer.'**
  String appointmentDurationHint(int hours);

  /// No description provided for @durationHours.
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat'**
  String durationHours(int hours);

  /// No description provided for @slotBooked.
  ///
  /// In tr, this message translates to:
  /// **'Dolu'**
  String get slotBooked;

  /// No description provided for @dayFull.
  ///
  /// In tr, this message translates to:
  /// **'Dolu'**
  String get dayFull;

  /// No description provided for @dayClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get dayClosed;

  /// No description provided for @calendarLegend.
  ///
  /// In tr, this message translates to:
  /// **'Takvim'**
  String get calendarLegend;

  /// No description provided for @monthAvailabilityUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Doluluk bilgisi alınamadı. Günler işaretlenmemiş olabilir.'**
  String get monthAvailabilityUnavailable;

  /// No description provided for @continueLabel.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get continueLabel;

  /// No description provided for @yourDetails.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileriniz'**
  String get yourDetails;

  /// No description provided for @pleaseEnterYourInformation.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bilgilerinizi girin'**
  String get pleaseEnterYourInformation;

  /// No description provided for @firstName.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In tr, this message translates to:
  /// **'Soyad'**
  String get lastName;

  /// No description provided for @phoneNumber.
  ///
  /// In tr, this message translates to:
  /// **'Telefon Numarası'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In tr, this message translates to:
  /// **'(555) 555 55 55'**
  String get phoneHint;

  /// No description provided for @detailsPrivacyNote.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileriniz bu cihazda kalır ve yalnızca bu randevu için kullanılır.'**
  String get detailsPrivacyNote;

  /// No description provided for @firstNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen adınızı girin.'**
  String get firstNameRequired;

  /// No description provided for @lastNameOptional.
  ///
  /// In tr, this message translates to:
  /// **'Soyad (isteğe bağlı)'**
  String get lastNameOptional;

  /// No description provided for @lastNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen soyadınızı girin.'**
  String get lastNameRequired;

  /// No description provided for @firstNameTooShort.
  ///
  /// In tr, this message translates to:
  /// **'Bu ad çok kısa görünüyor.'**
  String get firstNameTooShort;

  /// No description provided for @lastNameTooShort.
  ///
  /// In tr, this message translates to:
  /// **'Bu soyad çok kısa görünüyor.'**
  String get lastNameTooShort;

  /// No description provided for @phoneRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen telefon numaranızı girin.'**
  String get phoneRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Numarayı (555) 555 55 55 biçiminde girin.'**
  String get phoneInvalid;

  /// No description provided for @selectServiceOptional.
  ///
  /// In tr, this message translates to:
  /// **'Hizmet Seçin (İsteğe Bağlı)'**
  String get selectServiceOptional;

  /// No description provided for @chooseTheServiceYouWant.
  ///
  /// In tr, this message translates to:
  /// **'İstediğiniz hizmeti seçin'**
  String get chooseTheServiceYouWant;

  /// No description provided for @skipThisStep.
  ///
  /// In tr, this message translates to:
  /// **'Bu adımı atla'**
  String get skipThisStep;

  /// No description provided for @serviceClassicManicure.
  ///
  /// In tr, this message translates to:
  /// **'Klasik Manikür'**
  String get serviceClassicManicure;

  /// No description provided for @serviceGelManicure.
  ///
  /// In tr, this message translates to:
  /// **'Jel Manikür'**
  String get serviceGelManicure;

  /// No description provided for @serviceNailArtDesign.
  ///
  /// In tr, this message translates to:
  /// **'Nail Art Tasarım'**
  String get serviceNailArtDesign;

  /// No description provided for @servicePedicure.
  ///
  /// In tr, this message translates to:
  /// **'Pedikür'**
  String get servicePedicure;

  /// No description provided for @serviceNotSelected.
  ///
  /// In tr, this message translates to:
  /// **'Seçilmedi'**
  String get serviceNotSelected;

  /// No description provided for @serviceNotSelectedOnCard.
  ///
  /// In tr, this message translates to:
  /// **'Hizmet seçilmedi'**
  String get serviceNotSelectedOnCard;

  /// No description provided for @reviewAndConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Gözden Geçir ve Onayla'**
  String get reviewAndConfirm;

  /// No description provided for @appointmentDetails.
  ///
  /// In tr, this message translates to:
  /// **'Randevu Bilgileri'**
  String get appointmentDetails;

  /// No description provided for @labelDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get labelDate;

  /// No description provided for @labelTime.
  ///
  /// In tr, this message translates to:
  /// **'Saat'**
  String get labelTime;

  /// No description provided for @labelService.
  ///
  /// In tr, this message translates to:
  /// **'Hizmet'**
  String get labelService;

  /// No description provided for @labelPrice.
  ///
  /// In tr, this message translates to:
  /// **'Ücret'**
  String get labelPrice;

  /// No description provided for @labelDuration.
  ///
  /// In tr, this message translates to:
  /// **'Süre'**
  String get labelDuration;

  /// No description provided for @yourInformation.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileriniz'**
  String get yourInformation;

  /// No description provided for @labelName.
  ///
  /// In tr, this message translates to:
  /// **'Ad Soyad'**
  String get labelName;

  /// No description provided for @labelPhone.
  ///
  /// In tr, this message translates to:
  /// **'Telefon'**
  String get labelPhone;

  /// No description provided for @reviewEditHint.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklik mi gerekiyor? Geri dönerek düzenleyebilirsiniz.'**
  String get reviewEditHint;

  /// No description provided for @confirmAppointment.
  ///
  /// In tr, this message translates to:
  /// **'Randevuyu Onayla'**
  String get confirmAppointment;

  /// No description provided for @slotTakenMeanwhile.
  ///
  /// In tr, this message translates to:
  /// **'Bu saat az önce doldu. Lütfen başka bir saat seçin.'**
  String get slotTakenMeanwhile;

  /// No description provided for @appointmentConfirmed.
  ///
  /// In tr, this message translates to:
  /// **'Randevunuz\nOnaylandı!'**
  String get appointmentConfirmed;

  /// No description provided for @thankYouMessage.
  ///
  /// In tr, this message translates to:
  /// **'Teşekkürler, {name}!\nSizi görmeyi dört gözle bekliyoruz.'**
  String thankYouMessage(String name);

  /// No description provided for @backToHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfaya Dön'**
  String get backToHome;

  /// No description provided for @myAppointments.
  ///
  /// In tr, this message translates to:
  /// **'Randevularım'**
  String get myAppointments;

  /// No description provided for @sectionUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan'**
  String get sectionUpcoming;

  /// No description provided for @sectionPast.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get sectionPast;

  /// No description provided for @upcomingAppointment.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan Randevu'**
  String get upcomingAppointment;

  /// No description provided for @completedAppointment.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanan Randevu'**
  String get completedAppointment;

  /// No description provided for @statusConfirmed.
  ///
  /// In tr, this message translates to:
  /// **'Onaylı'**
  String get statusConfirmed;

  /// No description provided for @statusCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Yapıldı'**
  String get statusCompleted;

  /// No description provided for @addNewAppointment.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Randevu Ekle'**
  String get addNewAppointment;

  /// No description provided for @noAppointmentsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz randevunuz yok'**
  String get noAppointmentsTitle;

  /// No description provided for @noAppointmentsMessage.
  ///
  /// In tr, this message translates to:
  /// **'İlk randevunuzu oluşturduğunuzda burada görünecek.'**
  String get noAppointmentsMessage;

  /// No description provided for @nothingComingUp.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan randevunuz yok — yenisini oluşturun.'**
  String get nothingComingUp;

  /// No description provided for @cancelAppointment.
  ///
  /// In tr, this message translates to:
  /// **'Randevuyu iptal et'**
  String get cancelAppointment;

  /// No description provided for @cancelAppointmentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Randevu iptal edilsin mi?'**
  String get cancelAppointmentTitle;

  /// No description provided for @cancelAppointmentBody.
  ///
  /// In tr, this message translates to:
  /// **'{date} tarihli {time} randevunuz silinecek.'**
  String cancelAppointmentBody(String date, String time);

  /// No description provided for @keepIt.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get keepIt;

  /// No description provided for @cancelBooking.
  ///
  /// In tr, this message translates to:
  /// **'Randevuyu iptal et'**
  String get cancelBooking;

  /// No description provided for @profileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @guest.
  ///
  /// In tr, this message translates to:
  /// **'Misafir'**
  String get guest;

  /// No description provided for @bookOnceToSaveDetails.
  ///
  /// In tr, this message translates to:
  /// **'Bilgilerinizin kaydedilmesi için bir randevu oluşturun'**
  String get bookOnceToSaveDetails;

  /// No description provided for @statUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan'**
  String get statUpcoming;

  /// No description provided for @statCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanan'**
  String get statCompleted;

  /// No description provided for @salon.
  ///
  /// In tr, this message translates to:
  /// **'Salon'**
  String get salon;

  /// No description provided for @openingHours.
  ///
  /// In tr, this message translates to:
  /// **'Çalışma saatleri'**
  String get openingHours;

  /// No description provided for @openingHoursValue.
  ///
  /// In tr, this message translates to:
  /// **'10:00 – 22:00, her gün'**
  String get openingHoursValue;

  /// No description provided for @appointmentLength.
  ///
  /// In tr, this message translates to:
  /// **'Randevu süresi'**
  String get appointmentLength;

  /// No description provided for @appointmentLengthValue.
  ///
  /// In tr, this message translates to:
  /// **'Her randevu {hours} saat sürer'**
  String appointmentLengthValue(int hours);

  /// No description provided for @yourData.
  ///
  /// In tr, this message translates to:
  /// **'Verileriniz'**
  String get yourData;

  /// No description provided for @yourDataValue.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca bu cihazda saklanır'**
  String get yourDataValue;

  /// No description provided for @version.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {number}'**
  String version(String number);

  /// No description provided for @slotJustTaken.
  ///
  /// In tr, this message translates to:
  /// **'Bu saat az önce başkası tarafından alındı. Lütfen başka bir saat seçin.'**
  String get slotJustTaken;

  /// No description provided for @slotInThePast.
  ///
  /// In tr, this message translates to:
  /// **'Bu saat geçti. Lütfen ileri bir tarih seçin.'**
  String get slotInThePast;

  /// No description provided for @bookingWindow.
  ///
  /// In tr, this message translates to:
  /// **'Üç haftada bir randevu alabilirsiniz. Mevcut randevunuz duruyor.'**
  String get bookingWindow;

  /// No description provided for @bookingWindowUntil.
  ///
  /// In tr, this message translates to:
  /// **'Üç haftada bir randevu alabilirsiniz. En erken {date} tarihine randevu alabilirsiniz.'**
  String bookingWindowUntil(String date);

  /// No description provided for @salonClosedThatDay.
  ///
  /// In tr, this message translates to:
  /// **'Salon o gün kapalı. Lütfen başka bir gün seçin.'**
  String get salonClosedThatDay;

  /// No description provided for @cancelTooLate.
  ///
  /// In tr, this message translates to:
  /// **'Randevunuza bir saatten az kaldı. İptal için lütfen salonu arayın.'**
  String get cancelTooLate;

  /// No description provided for @nameDoesNotMatch.
  ///
  /// In tr, this message translates to:
  /// **'Bu telefon numarası için girdiğiniz ad kayıtlı bilgiyle eşleşmiyor. Lütfen kontrol edin.'**
  String get nameDoesNotMatch;

  /// No description provided for @connectionProblem.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı kurulamadı. İnternetinizi kontrol edip tekrar deneyin.'**
  String get connectionProblem;

  /// No description provided for @somethingWentWrong.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti. Lütfen tekrar deneyin.'**
  String get somethingWentWrong;

  /// No description provided for @saveChange.
  ///
  /// In tr, this message translates to:
  /// **'Değişikliği kaydet'**
  String get saveChange;

  /// No description provided for @appointmentMoved.
  ///
  /// In tr, this message translates to:
  /// **'Randevunuz taşındı.'**
  String get appointmentMoved;

  /// No description provided for @changeAppointment.
  ///
  /// In tr, this message translates to:
  /// **'Randevuyu değiştir'**
  String get changeAppointment;

  /// No description provided for @editProfile.
  ///
  /// In tr, this message translates to:
  /// **'Bilgilerimi düzenle'**
  String get editProfile;

  /// No description provided for @profileSaved.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileriniz kaydedildi.'**
  String get profileSaved;

  /// No description provided for @save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// No description provided for @change.
  ///
  /// In tr, this message translates to:
  /// **'Değiştir'**
  String get change;

  /// No description provided for @profilePhoneNote.
  ///
  /// In tr, this message translates to:
  /// **'Telefon numaranız sizi tanımlar; değiştirirseniz randevularınız yeni numarayla eşleşir. Geçmiş randevularınız alındıkları bilgilerle kalır.'**
  String get profilePhoneNote;

  /// No description provided for @adminMenu.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim'**
  String get adminMenu;

  /// No description provided for @adminCustomers.
  ///
  /// In tr, this message translates to:
  /// **'Kişiler'**
  String get adminCustomers;

  /// No description provided for @adminServices.
  ///
  /// In tr, this message translates to:
  /// **'Hizmetler ve fiyatlar'**
  String get adminServices;

  /// No description provided for @adminClosures.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı günler'**
  String get adminClosures;

  /// No description provided for @adminStats.
  ///
  /// In tr, this message translates to:
  /// **'İstatistik'**
  String get adminStats;

  /// No description provided for @adminNewBooking.
  ///
  /// In tr, this message translates to:
  /// **'Yeni randevu'**
  String get adminNewBooking;

  /// No description provided for @markCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Yapıldı olarak işaretle'**
  String get markCompleted;

  /// No description provided for @markNoShow.
  ///
  /// In tr, this message translates to:
  /// **'Gelmedi olarak işaretle'**
  String get markNoShow;

  /// No description provided for @markNoShowNote.
  ///
  /// In tr, this message translates to:
  /// **'Gelmedi işaretlemek bu kişinin üç haftalık kısıtını kaldırır; hemen yeni randevu alabilir.'**
  String get markNoShowNote;

  /// No description provided for @statusCancelled.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get statusCancelled;

  /// No description provided for @statusNoShow.
  ///
  /// In tr, this message translates to:
  /// **'Gelmedi'**
  String get statusNoShow;

  /// No description provided for @appointmentTotal.
  ///
  /// In tr, this message translates to:
  /// **'Toplam'**
  String get appointmentTotal;

  /// No description provided for @appointmentServices.
  ///
  /// In tr, this message translates to:
  /// **'Yapılan işlemler'**
  String get appointmentServices;

  /// No description provided for @addExtra.
  ///
  /// In tr, this message translates to:
  /// **'İşlem ekle'**
  String get addExtra;

  /// No description provided for @removeLine.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get removeLine;

  /// No description provided for @amountLabel.
  ///
  /// In tr, this message translates to:
  /// **'Tutar'**
  String get amountLabel;

  /// No description provided for @noLineItems.
  ///
  /// In tr, this message translates to:
  /// **'Henüz işlem eklenmedi.'**
  String get noLineItems;

  /// No description provided for @customerSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Ad veya telefon ara'**
  String get customerSearchHint;

  /// No description provided for @archiveCustomer.
  ///
  /// In tr, this message translates to:
  /// **'Arşivle'**
  String get archiveCustomer;

  /// No description provided for @restoreCustomer.
  ///
  /// In tr, this message translates to:
  /// **'Geri getir'**
  String get restoreCustomer;

  /// No description provided for @showArchived.
  ///
  /// In tr, this message translates to:
  /// **'Arşivdekileri göster'**
  String get showArchived;

  /// No description provided for @archivedLabel.
  ///
  /// In tr, this message translates to:
  /// **'Arşivde'**
  String get archivedLabel;

  /// No description provided for @noCustomers.
  ///
  /// In tr, this message translates to:
  /// **'Kişi bulunamadı.'**
  String get noCustomers;

  /// No description provided for @editCustomer.
  ///
  /// In tr, this message translates to:
  /// **'Kişiyi düzenle'**
  String get editCustomer;

  /// No description provided for @serviceTreatments.
  ///
  /// In tr, this message translates to:
  /// **'İşlemler'**
  String get serviceTreatments;

  /// No description provided for @serviceExtras.
  ///
  /// In tr, this message translates to:
  /// **'Ekstralar'**
  String get serviceExtras;

  /// No description provided for @serviceInactive.
  ///
  /// In tr, this message translates to:
  /// **'Menüde değil'**
  String get serviceInactive;

  /// No description provided for @editService.
  ///
  /// In tr, this message translates to:
  /// **'Hizmeti düzenle'**
  String get editService;

  /// No description provided for @priceMinLabel.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat'**
  String get priceMinLabel;

  /// No description provided for @priceMaxLabel.
  ///
  /// In tr, this message translates to:
  /// **'Üst sınır (aralıklıysa)'**
  String get priceMaxLabel;

  /// No description provided for @serviceNameTrLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ad (Türkçe)'**
  String get serviceNameTrLabel;

  /// No description provided for @serviceNameEnLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ad (İngilizce)'**
  String get serviceNameEnLabel;

  /// No description provided for @closureAdd.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı gün ekle'**
  String get closureAdd;

  /// No description provided for @closureFrom.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get closureFrom;

  /// No description provided for @closureTo.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş'**
  String get closureTo;

  /// No description provided for @closureReason.
  ///
  /// In tr, this message translates to:
  /// **'Sebep (isteğe bağlı)'**
  String get closureReason;

  /// No description provided for @noClosures.
  ///
  /// In tr, this message translates to:
  /// **'İlan edilmiş kapalı gün yok.'**
  String get noClosures;

  /// No description provided for @closureRemoved.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı gün kaldırıldı.'**
  String get closureRemoved;

  /// No description provided for @sundayAlwaysClosed.
  ///
  /// In tr, this message translates to:
  /// **'Pazar günleri zaten kapalı; burada ayrıca eklemeye gerek yok.'**
  String get sundayAlwaysClosed;

  /// No description provided for @statsThisMonth.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay'**
  String get statsThisMonth;

  /// No description provided for @statsLastMonth.
  ///
  /// In tr, this message translates to:
  /// **'Geçen ay'**
  String get statsLastMonth;

  /// No description provided for @statsThisYear.
  ///
  /// In tr, this message translates to:
  /// **'Bu yıl'**
  String get statsThisYear;

  /// No description provided for @statsCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Yapılan'**
  String get statsCompleted;

  /// No description provided for @statsCancelled.
  ///
  /// In tr, this message translates to:
  /// **'İptal edilen'**
  String get statsCancelled;

  /// No description provided for @statsNoShow.
  ///
  /// In tr, this message translates to:
  /// **'Gelmeyen'**
  String get statsNoShow;

  /// No description provided for @statsRevenue.
  ///
  /// In tr, this message translates to:
  /// **'Kazanılan'**
  String get statsRevenue;

  /// No description provided for @statsRevenueNote.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca girilmiş işlem tutarları toplanır. Tutarı girilmemiş randevular sıfır sayılır.'**
  String get statsRevenueNote;

  /// No description provided for @statsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönemde randevu yok.'**
  String get statsEmpty;

  /// No description provided for @newBookingFor.
  ///
  /// In tr, this message translates to:
  /// **'Kime'**
  String get newBookingFor;

  /// No description provided for @newBookingSaved.
  ///
  /// In tr, this message translates to:
  /// **'Randevu oluşturuldu.'**
  String get newBookingSaved;

  /// No description provided for @pickDay.
  ///
  /// In tr, this message translates to:
  /// **'Gün seç'**
  String get pickDay;

  /// No description provided for @pickHour.
  ///
  /// In tr, this message translates to:
  /// **'Saat seç'**
  String get pickHour;

  /// No description provided for @adminBookingNote.
  ///
  /// In tr, this message translates to:
  /// **'Salon adına girilen randevular üç haftalık kısıttan ve kapalı gün kuralından muaftır.'**
  String get adminBookingNote;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retry;

  /// No description provided for @loadingAvailability.
  ///
  /// In tr, this message translates to:
  /// **'Uygun saatler yükleniyor…'**
  String get loadingAvailability;

  /// No description provided for @availabilityUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Dolu saatler alınamadı. Seçiminiz onay sırasında kontrol edilecek.'**
  String get availabilityUnavailable;

  /// No description provided for @offlineShowingCached.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışısınız. Son bilinen randevularınız gösteriliyor.'**
  String get offlineShowingCached;

  /// No description provided for @couldNotLoadAppointments.
  ///
  /// In tr, this message translates to:
  /// **'Randevularınız yüklenemedi.'**
  String get couldNotLoadAppointments;

  /// No description provided for @booking.
  ///
  /// In tr, this message translates to:
  /// **'Randevu oluşturuluyor…'**
  String get booking;

  /// No description provided for @anonymousSignInDisabled.
  ///
  /// In tr, this message translates to:
  /// **'Supabase projesinde anonim girişler kapalı. Authentication → Providers bölümünden açıp uygulamayı yeniden başlatın.'**
  String get anonymousSignInDisabled;

  /// No description provided for @setupRequiredTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kurulum gerekli'**
  String get setupRequiredTitle;

  /// No description provided for @setupRequiredMessage.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama Supabase bilgileri olmadan derlenmiş. SUPABASE_URL ve SUPABASE_ANON_KEY değerlerini --dart-define ile verip yeniden başlatın.'**
  String get setupRequiredMessage;

  /// No description provided for @language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In tr, this message translates to:
  /// **'Cihaz dili'**
  String get languageSystem;

  /// No description provided for @languageTurkish.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// No description provided for @languageEnglish.
  ///
  /// In tr, this message translates to:
  /// **'İngilizce'**
  String get languageEnglish;

  /// No description provided for @adminStaffLogin.
  ///
  /// In tr, this message translates to:
  /// **'Personel girişi'**
  String get adminStaffLogin;

  /// No description provided for @adminLoginTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici Girişi'**
  String get adminLoginTitle;

  /// No description provided for @adminLoginSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Personel hesabınızla giriş yapın'**
  String get adminLoginSubtitle;

  /// No description provided for @adminEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get adminEmail;

  /// No description provided for @adminPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get adminPassword;

  /// No description provided for @adminEmailRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen e-postanızı girin.'**
  String get adminEmailRequired;

  /// No description provided for @adminPasswordRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen şifrenizi girin.'**
  String get adminPasswordRequired;

  /// No description provided for @adminSignIn.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get adminSignIn;

  /// No description provided for @adminInvalidCredentials.
  ///
  /// In tr, this message translates to:
  /// **'E-posta veya şifre hatalı.'**
  String get adminInvalidCredentials;

  /// No description provided for @adminNotAuthorized.
  ///
  /// In tr, this message translates to:
  /// **'Bu hesabın yönetici yetkisi yok.'**
  String get adminNotAuthorized;

  /// No description provided for @adminAppointmentsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm Randevular'**
  String get adminAppointmentsTitle;

  /// No description provided for @adminScheduleTitle.
  ///
  /// In tr, this message translates to:
  /// **'Randevu Takvimi'**
  String get adminScheduleTitle;

  /// No description provided for @adminToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get adminToday;

  /// No description provided for @adminSignOut.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get adminSignOut;

  /// No description provided for @adminUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan'**
  String get adminUpcoming;

  /// No description provided for @adminNoAppointmentsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan randevu yok'**
  String get adminNoAppointmentsTitle;

  /// No description provided for @adminNoAppointmentsMessage.
  ///
  /// In tr, this message translates to:
  /// **'Yeni randevular burada görünecek.'**
  String get adminNoAppointmentsMessage;

  /// No description provided for @adminNoAppointmentsOnDay.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için randevu yok.'**
  String get adminNoAppointmentsOnDay;

  /// No description provided for @adminDayAppointmentCount.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =0{Randevu yok} =1{1 randevu} other{{count} randevu}}'**
  String adminDayAppointmentCount(int count);

  /// No description provided for @adminCouldNotLoad.
  ///
  /// In tr, this message translates to:
  /// **'Randevular yüklenemedi.'**
  String get adminCouldNotLoad;

  /// No description provided for @adminCancelConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'{name} adlı müşterinin {date} tarihli {time} randevusu iptal edilecek.'**
  String adminCancelConfirmBody(String name, String date, String time);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
