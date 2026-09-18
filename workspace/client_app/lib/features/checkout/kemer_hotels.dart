import '../../core/content/app_content.dart';

/// Отели Кемера, в которые возит курьер.
///
/// Список приходит из настроек (`workspace/content/hotels.json`) вместе с
/// адресами и координатами. Свободный ввод названия сознательно не даём: это
/// опечатки в адресе доставки и курьер, который едет не туда.
List<String> get kemerHotels =>
    [for (final hotel in AppContent.instance.hotels) hotel.name];

/// Отель по умолчанию для чекаута: из профиля, если он есть в списке.
///
/// Профиль мог заполняться до того, как список отелей поменяли, поэтому
/// проверка на вхождение обязательна: значение `DropdownButton`, которого
/// нет среди `items`, роняет виджет ассертом.
String defaultKemerHotel(String? profileHotel) {
  final hotels = kemerHotels;
  if (profileHotel != null && hotels.contains(profileHotel)) {
    return profileHotel;
  }
  return hotels.first;
}
