import 'package:intl/intl.dart';

/// Формат цены — тот же, что в клиентском приложении
/// (`client_app/lib/core/format.dart`): «1 250 ₽», разделитель разрядов —
/// НЕРАЗРЫВНЫЙ пробел (U+00A0).
///
/// Раньше суммы собирались на месте через `toStringAsFixed(2)`, и курьер
/// видел «5430.00 ₽» там, где клиент в своём приложении видит «5 430 ₽» —
/// одна и та же сумма двумя разными способами. Копейки в каталоге не
/// встречаются, печатать их незачем.
///
/// Неразрывный пробел записан кодом, а не символом: в исходнике он
/// неотличим глазами от обычного, и следующая правка сломала бы формат
/// молча — цена «1 250 ₽» переносилась бы между «1» и «250».
final NumberFormat _rub = NumberFormat.decimalPattern('ru_RU');

String money(double v) {
  final rounded = v.roundToDouble();
  final digits = _rub
      .format(rounded.abs().toInt())
      .replaceAll(' ', ' ')
      .replaceAll(' ', ' ');
  final sign = rounded < 0 ? '−' : '';
  return '$sign$digits ₽';
}

/// Время заказа: «14:05». Дату не печатаем — курьер работает со сменой,
/// и день у всех заказов на экране один и тот же.
String timeOfDay(DateTime value) => DateFormat.Hm().format(value);
