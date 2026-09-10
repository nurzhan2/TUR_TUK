// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'TUR TUK Kurye';

  @override
  String get authTitle => 'Kurye girişi';

  @override
  String get phoneLabel => 'Telefon numarası';

  @override
  String get phoneHint => '+90 5xx xxx xx xx';

  @override
  String get sendCodeButton => 'Kod gönder';

  @override
  String get codeLabel => 'SMS kodu';

  @override
  String get codeHint => '0000';

  @override
  String get verifyCodeButton => 'Onayla';

  @override
  String get resendCodeButton => 'Kodu tekrar gönder';

  @override
  String get changePhoneButton => 'Numarayı değiştir';

  @override
  String get authGenericError => 'Giriş yapılamadı. Lütfen tekrar deneyin.';

  @override
  String get authInvalidCode => 'Kod hatalı veya süresi geçmiş';

  @override
  String get authPhoneRequired => 'Telefon numaranızı girin';

  @override
  String get authCodeRequired => 'SMS ile gelen kodu girin';

  @override
  String get ordersTitle => 'Siparişler';

  @override
  String get ordersEmpty => 'Henüz sipariş yok';

  @override
  String get ordersLoadError => 'Siparişler yüklenemedi';

  @override
  String get ordersRetryButton => 'Tekrar dene';

  @override
  String orderNumber(int id) {
    return 'Sipariş #$id';
  }

  @override
  String get sectionNew => 'Yeni';

  @override
  String get sectionInProgress => 'Devam eden';

  @override
  String get sectionDone => 'Tamamlanan';

  @override
  String get sectionEmpty => 'Burada henüz bir şey yok';

  @override
  String orderAddress(String hotel, String room) {
    return '$hotel, oda $room';
  }

  @override
  String orderItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ürün',
      one: '$count ürün',
    );
    return '$_temp0';
  }

  @override
  String get orderNotFound => 'Sipariş bulunamadı';

  @override
  String get orderItemsTitle => 'Sipariş içeriği';

  @override
  String get orderItemsUnavailable => 'Sipariş içeriği görüntülenemiyor';

  @override
  String get orderClientTitle => 'Müşteri';

  @override
  String get orderCall => 'Ara';

  @override
  String get orderHotel => 'Otel';

  @override
  String get orderRoom => 'Oda numarası';

  @override
  String get orderTotal => 'Sipariş tutarı';

  @override
  String orderCreatedAt(String time) {
    return '$time tarihinde verildi';
  }

  @override
  String get orderStatusCreated => 'yeni';

  @override
  String get orderStatusAccepted => 'kabul edildi';

  @override
  String get orderStatusAssembling => 'hazırlanıyor';

  @override
  String get orderStatusDelivering => 'yolda';

  @override
  String get orderStatusDelivered => 'teslim edildi';

  @override
  String get orderStatusCancelled => 'iptal edildi';

  @override
  String get actionAccept => 'Kabul et';

  @override
  String get actionReject => 'Reddet';

  @override
  String get actionStartAssembly => 'Hazırlamaya başla';

  @override
  String get actionDepart => 'Yola çıktım';

  @override
  String get actionDelivered => 'Teslim edildi';

  @override
  String get actionRoute => 'Güzergâh';

  @override
  String get actionCancel => 'Vazgeç';

  @override
  String get rejectConfirmTitle => 'Sipariş reddedilsin mi?';

  @override
  String get rejectConfirmText =>
      'Sipariş dispeçere geri döner. Bu işlem uygulamadan geri alınamaz.';

  @override
  String get deliveryTitle => 'Teslim onayı';

  @override
  String get deliveryHint =>
      'Kutuyu resepsiyonda fotoğraflayın — fotoğraf teslimi doğrular.';

  @override
  String get deliveryTakePhoto => 'Kutuyu fotoğrafla';

  @override
  String get deliveryRetakePhoto => 'Başka bir fotoğraf çek';

  @override
  String get deliveryConfirm => 'Teslimi onayla';

  @override
  String get deliveryDone => 'Sipariş teslim edildi';

  @override
  String get deliveryPhotoTitle => 'Teslim fotoğrafı';

  @override
  String get routeTitle => 'Güzergâh';

  @override
  String get routeCourier => 'Kurye';

  @override
  String get routeOpenInNavigator => 'Navigasyonda aç';

  @override
  String get routeLaunchFailed => 'Navigasyon uygulaması açılamadı';

  @override
  String get logoutButton => 'Çıkış yap';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageTr => 'Türkçe';
}
