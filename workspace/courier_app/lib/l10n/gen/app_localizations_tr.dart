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
  String get authGenericError => 'Giriş başarısız. Lütfen tekrar deneyin.';

  @override
  String get authInvalidCode => 'Kod hatalı veya süresi dolmuş';

  @override
  String get authPhoneRequired => 'Telefon numaranızı girin';

  @override
  String get authCodeRequired => 'SMS kodunu girin';

  @override
  String get ordersTitle => 'Yeni siparişler';

  @override
  String get ordersEmpty => 'Henüz yeni sipariş yok';

  @override
  String get ordersLoadError => 'Siparişler yüklenemedi';

  @override
  String get ordersRetryButton => 'Tekrar dene';

  @override
  String orderNumber(int id) {
    return 'Sipariş №$id';
  }

  @override
  String get orderStatusCreated => 'oluşturuldu';

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
  String get logoutButton => 'Çıkış yap';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageTr => 'Türkçe';
}
