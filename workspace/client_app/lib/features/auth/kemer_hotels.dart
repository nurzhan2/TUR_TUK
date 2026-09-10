/// Отели Кемера, куда TUR TUK возит заказы.
///
/// Список лежит в фичах, а не в общем слое данных: он ещё не согласован с
/// заказчицей (в брифе отели названы примерами, финального перечня нет),
/// и когда он приедет — правится одно место без похода в модели.
///
/// Сессия чекаута держит свою копию такого же списка. Дублирование здесь
/// осознанное: связывать две параллельные ветки общим файлом дороже, чем
/// продублировать восемь строк, а свести их в один источник — работа на
/// пять минут после мержа.
const List<String> kemerHotels = [
  'Rixos Sungate',
  'Club Med Palmiye',
  'Maxx Royal Kemer',
  'Amara Prestige',
  'Crystal Sunset Luxury',
  'Orange County Kemer',
  'Akra Kemer',
  'Sherwood Exclusive Kemer',
];

/// Отель профиля, если он есть в списке, иначе первый.
///
/// Гостья могла заселиться в отель, которого в перечне пока нет — тогда
/// подставлять «пусто» нельзя, форма встанет с невалидным значением.
String resolveHotel(String? profileHotel) {
  if (profileHotel != null && kemerHotels.contains(profileHotel)) {
    return profileHotel;
  }
  return kemerHotels.first;
}
