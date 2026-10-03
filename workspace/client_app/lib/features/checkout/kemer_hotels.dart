import '../../core/content/app_content.dart';

/// Отели Кемера, в которые возим заказы — из админки (или ассетов в демо).
List<String> get kemerHotels =>
    [for (final hotel in AppContent.instance.hotels) hotel.name];

/// Отель по умолчанию для чекаута: из профиля, если он есть в списке.
///
/// Иначе — пусто: гость выбирает сам. Подставлять «первый по алфавиту»
/// нельзя — заказ уедет в чужой отель, а гость этого не заметит.
String defaultKemerHotel(String? profileHotel) {
  if (profileHotel != null && kemerHotels.contains(profileHotel)) {
    return profileHotel;
  }
  return '';
}
