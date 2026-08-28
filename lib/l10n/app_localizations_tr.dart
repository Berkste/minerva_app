// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Minerva Nail Art';

  @override
  String get dateFullPattern => 'd MMMM yyyy EEEE';

  @override
  String get dateShortPattern => 'd MMM yyyy';

  @override
  String get monthYearPattern => 'MMMM yyyy';

  @override
  String get splashTagline => 'Güzel tırnaklar,\nmükemmel zaman.';

  @override
  String get getStarted => 'Başlayalım';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navAppointments => 'Randevular';

  @override
  String get navProfile => 'Profil';

  @override
  String get heroTitle => 'Güzelliğiniz,\nbizim tutkumuz.';

  @override
  String get heroSubtitle => 'Randevunuzu kolay ve\nhızlı bir şekilde alın.';

  @override
  String get newAppointment => 'Yeni Randevu';

  @override
  String get myNextAppointment => 'Sonraki Randevum';

  @override
  String get seeAll => 'Tümünü gör';

  @override
  String get noAppointmentYet => 'Henüz randevunuz yok';

  @override
  String get noAppointmentYetHint =>
      'Randevu almak için \"Yeni Randevu\"ya dokunun.';

  @override
  String get ourServices => 'Hizmetlerimiz';

  @override
  String get calendarTitle => 'Takvim';

  @override
  String get selectedDate => 'Seçilen Tarih';

  @override
  String get pickADayAbove => 'Yukarıdan bir gün seçin';

  @override
  String get selectTime => 'Saat Seç';

  @override
  String appointmentDurationHint(int hours) {
    return 'Her randevu $hours saat sürer.';
  }

  @override
  String durationHours(int hours) {
    return '$hours saat';
  }

  @override
  String get slotBooked => 'Dolu';

  @override
  String get continueLabel => 'Devam';

  @override
  String get yourDetails => 'Bilgileriniz';

  @override
  String get pleaseEnterYourInformation => 'Lütfen bilgilerinizi girin';

  @override
  String get firstName => 'Ad';

  @override
  String get lastName => 'Soyad';

  @override
  String get phoneNumber => 'Telefon Numarası';

  @override
  String get phoneHint => '(555) 555 55 55';

  @override
  String get detailsPrivacyNote =>
      'Bilgileriniz bu cihazda kalır ve yalnızca bu randevu için kullanılır.';

  @override
  String get firstNameRequired => 'Lütfen adınızı girin.';

  @override
  String get lastNameRequired => 'Lütfen soyadınızı girin.';

  @override
  String get firstNameTooShort => 'Bu ad çok kısa görünüyor.';

  @override
  String get lastNameTooShort => 'Bu soyad çok kısa görünüyor.';

  @override
  String get phoneRequired => 'Lütfen telefon numaranızı girin.';

  @override
  String get phoneInvalid => 'Numarayı (555) 555 55 55 biçiminde girin.';

  @override
  String get selectServiceOptional => 'Hizmet Seçin (İsteğe Bağlı)';

  @override
  String get chooseTheServiceYouWant => 'İstediğiniz hizmeti seçin';

  @override
  String get skipThisStep => 'Bu adımı atla';

  @override
  String get serviceClassicManicure => 'Klasik Manikür';

  @override
  String get serviceGelManicure => 'Jel Manikür';

  @override
  String get serviceNailArtDesign => 'Nail Art Tasarım';

  @override
  String get servicePedicure => 'Pedikür';

  @override
  String get serviceNotSelected => 'Seçilmedi';

  @override
  String get serviceNotSelectedOnCard => 'Hizmet seçilmedi';

  @override
  String get reviewAndConfirm => 'Gözden Geçir ve Onayla';

  @override
  String get appointmentDetails => 'Randevu Bilgileri';

  @override
  String get labelDate => 'Tarih';

  @override
  String get labelTime => 'Saat';

  @override
  String get labelService => 'Hizmet';

  @override
  String get labelPrice => 'Ücret';

  @override
  String get labelDuration => 'Süre';

  @override
  String get yourInformation => 'Bilgileriniz';

  @override
  String get labelName => 'Ad Soyad';

  @override
  String get labelPhone => 'Telefon';

  @override
  String get reviewEditHint =>
      'Değişiklik mi gerekiyor? Geri dönerek düzenleyebilirsiniz.';

  @override
  String get confirmAppointment => 'Randevuyu Onayla';

  @override
  String get slotTakenMeanwhile =>
      'Bu saat az önce doldu. Lütfen başka bir saat seçin.';

  @override
  String get appointmentConfirmed => 'Randevunuz\nOnaylandı!';

  @override
  String thankYouMessage(String name) {
    return 'Teşekkürler, $name!\nSizi görmeyi dört gözle bekliyoruz.';
  }

  @override
  String get backToHome => 'Ana Sayfaya Dön';

  @override
  String get myAppointments => 'Randevularım';

  @override
  String get sectionUpcoming => 'Yaklaşan';

  @override
  String get sectionPast => 'Geçmiş';

  @override
  String get upcomingAppointment => 'Yaklaşan Randevu';

  @override
  String get completedAppointment => 'Tamamlanan Randevu';

  @override
  String get statusConfirmed => 'Onaylandı';

  @override
  String get statusCompleted => 'Tamamlandı';

  @override
  String get addNewAppointment => 'Yeni Randevu Ekle';

  @override
  String get noAppointmentsTitle => 'Henüz randevunuz yok';

  @override
  String get noAppointmentsMessage =>
      'İlk randevunuzu oluşturduğunuzda burada görünecek.';

  @override
  String get nothingComingUp => 'Yaklaşan randevunuz yok — yenisini oluşturun.';

  @override
  String get cancelAppointment => 'Randevuyu iptal et';

  @override
  String get cancelAppointmentTitle => 'Randevu iptal edilsin mi?';

  @override
  String cancelAppointmentBody(String date, String time) {
    return '$date tarihli $time randevunuz silinecek.';
  }

  @override
  String get keepIt => 'Vazgeç';

  @override
  String get cancelBooking => 'Randevuyu iptal et';

  @override
  String get profileTitle => 'Profil';

  @override
  String get guest => 'Misafir';

  @override
  String get bookOnceToSaveDetails =>
      'Bilgilerinizin kaydedilmesi için bir randevu oluşturun';

  @override
  String get statUpcoming => 'Yaklaşan';

  @override
  String get statCompleted => 'Tamamlanan';

  @override
  String get salon => 'Salon';

  @override
  String get openingHours => 'Çalışma saatleri';

  @override
  String get openingHoursValue => '10:00 – 22:00, her gün';

  @override
  String get appointmentLength => 'Randevu süresi';

  @override
  String appointmentLengthValue(int hours) {
    return 'Her randevu $hours saat sürer';
  }

  @override
  String get yourData => 'Verileriniz';

  @override
  String get yourDataValue => 'Yalnızca bu cihazda saklanır';

  @override
  String version(String number) {
    return 'Sürüm $number';
  }

  @override
  String get slotJustTaken =>
      'Bu saat az önce başkası tarafından alındı. Lütfen başka bir saat seçin.';

  @override
  String get slotInThePast => 'Bu saat geçti. Lütfen ileri bir tarih seçin.';

  @override
  String get connectionProblem =>
      'Bağlantı kurulamadı. İnternetinizi kontrol edip tekrar deneyin.';

  @override
  String get somethingWentWrong =>
      'Bir şeyler ters gitti. Lütfen tekrar deneyin.';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get loadingAvailability => 'Uygun saatler yükleniyor…';

  @override
  String get availabilityUnavailable =>
      'Dolu saatler alınamadı. Seçiminiz onay sırasında kontrol edilecek.';

  @override
  String get offlineShowingCached =>
      'Çevrimdışısınız. Son bilinen randevularınız gösteriliyor.';

  @override
  String get couldNotLoadAppointments => 'Randevularınız yüklenemedi.';

  @override
  String get booking => 'Randevu oluşturuluyor…';

  @override
  String get anonymousSignInDisabled =>
      'Supabase projesinde anonim girişler kapalı. Authentication → Providers bölümünden açıp uygulamayı yeniden başlatın.';

  @override
  String get setupRequiredTitle => 'Kurulum gerekli';

  @override
  String get setupRequiredMessage =>
      'Uygulama Supabase bilgileri olmadan derlenmiş. SUPABASE_URL ve SUPABASE_ANON_KEY değerlerini --dart-define ile verip yeniden başlatın.';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Cihaz dili';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'İngilizce';
}
