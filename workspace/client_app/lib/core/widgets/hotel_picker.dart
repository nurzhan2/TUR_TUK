import 'package:flutter/material.dart';

import '../content/app_content.dart';
import '../theme/app_theme.dart';

/// Поле выбора отеля с поиском.
///
/// Отелей в зоне доставки сотни (список ведётся в админке), и выпадающий
/// список на весь экран без поиска превращает регистрацию в прокрутку
/// алфавита. Тап по полю открывает шторку: поиск по названию и адресу,
/// крупные строки, выбранный отель отмечен.
class HotelPickerField extends StatelessWidget {
  const HotelPickerField({
    required this.value,
    required this.onChanged,
    this.label,
    this.prefixIcon,
    this.errorText,
    super.key,
  });

  /// Название выбранного отеля; пустая строка — ещё не выбран.
  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final Widget? prefixIcon;
  final String? errorText;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HotelSheet(selected: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radius),
      onTap: () => _open(context),
      child: InputDecorator(
        isEmpty: empty,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Выберите отель',
          prefixIcon: prefixIcon,
          errorText: errorText,
          suffixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        ),
        child: Text(
          empty ? '' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _HotelSheet extends StatefulWidget {
  const _HotelSheet({required this.selected});

  final String selected;

  @override
  State<_HotelSheet> createState() => _HotelSheetState();
}

class _HotelSheetState extends State<_HotelSheet> {
  final _query = TextEditingController();
  late final List<Hotel> _all = AppContent.instance.hotels;
  late List<Hotel> _shown = _all;

  void _filter(String raw) {
    final q = raw.trim().toLowerCase();
    setState(() {
      _shown = q.isEmpty
          ? _all
          : _all
              .where((h) =>
                  h.name.toLowerCase().contains(q) || h.address.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.85;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 0, AppSizes.pagePadding, 12),
              child: TextField(
                controller: _query,
                autofocus: _all.length > 12,
                onChanged: _filter,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Название или адрес отеля',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _query.clear();
                            _filter('');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: _shown.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Такого отеля нет в зоне доставки.\nНапишите в поддержку — проверим.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, height: 1.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _shown.length,
                      itemBuilder: (context, i) {
                        final hotel = _shown[i];
                        final selected = hotel.name == widget.selected;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
                          leading: Icon(
                            Icons.apartment_outlined,
                            color: selected ? AppColors.accent : AppColors.textMuted,
                          ),
                          title: Text(
                            hotel.name,
                            style: TextStyle(
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? AppColors.accent : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: hotel.address.isEmpty ? null : Text(hotel.address),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: AppColors.accent)
                              : null,
                          onTap: () => Navigator.of(context).pop(hotel.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
