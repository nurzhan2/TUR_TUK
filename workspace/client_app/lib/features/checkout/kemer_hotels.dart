/// Отели Кемера, в которые возит курьер.
///
/// Список зашит в приложение: справочника отелей на бэкенде нет
/// (`workspace/backend`), а свободный ввод названия в поле — это опечатки
/// в адресе доставки и курьер, который едет не туда.
const List<String> kemerHotels = <String>[
  'Rixos Sungate',
  'Club Med Palmiye',
  'Maxx Royal Kemer',
  'Amara Prestige',
  'Crystal Sunset Luxury',
  'Orange County Kemer',
  'Akra Kemer',
  'Sherwood Exclusive Kemer',
];

/// Отель по умолчанию для чекаута: из профиля, если он есть в списке.
///
/// Профиль мог заполняться до того, как список отелей поменяли, поэтому
/// проверка на вхождение обязательна: значение `DropdownButton`, которого
/// нет среди `items`, роняет виджет ассертом.
String defaultKemerHotel(String? profileHotel) {
  if (profileHotel != null && kemerHotels.contains(profileHotel)) {
    return profileHotel;
  }
  return kemerHotels.first;
}
