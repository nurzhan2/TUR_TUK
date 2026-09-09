import 'package:intl/intl.dart';

/// Дата заказа: «9 сентября, 14:30».
///
/// Локаль указана явно, а не берётся из интерфейса: содержимое заказов —
/// русское (названия товаров, имя курьера), и английский месяц посреди
/// такой карточки выглядел бы опечаткой.
///
/// Наличие данных локали ПРОВЕРЯЕТСЯ: символы `ru` подгружает делегат
/// локализации, и при запуске с другим языком их может не оказаться —
/// `DateFormat` тогда бросает прямо из `build`, унося весь экран.
String orderDateTime(DateTime value) {
  const pattern = 'd MMMM, HH:mm';
  return DateFormat.localeExists('ru')
      ? DateFormat(pattern, 'ru').format(value)
      : DateFormat(pattern).format(value);
}

/// Только время, «14:30» — для пройденных шагов таймлайна.
String orderTime(DateTime value) {
  const pattern = 'HH:mm';
  return DateFormat.localeExists('ru')
      ? DateFormat(pattern, 'ru').format(value)
      : DateFormat(pattern).format(value);
}
