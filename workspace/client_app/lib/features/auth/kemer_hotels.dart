import '../../core/content/app_content.dart';

/// Отели, куда TUR TUK возит заказы.
///
/// Список больше не зашит в код: он лежит в `workspace/content/hotels.json`
/// вместе с адресами и координатами, которые нужны карте курьера. Заказчица
/// присылает свой перечень — мы правим один файл и пересобираем.
List<String> get kemerHotels =>
    [for (final hotel in AppContent.instance.hotels) hotel.name];

/// Отель профиля, если он есть в списке, иначе первый.
///
/// Гостья могла заселиться в отель, которого в перечне пока нет — тогда
/// подставлять «пусто» нельзя, форма встанет с невалидным значением.
String resolveHotel(String? profileHotel) {
  final hotels = kemerHotels;
  if (profileHotel != null && hotels.contains(profileHotel)) {
    return profileHotel;
  }
  return hotels.first;
}
