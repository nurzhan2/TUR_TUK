import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/controller_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hotel_picker.dart';
import '../../l10n/gen/app_localizations.dart';

/// Анкета после подтверждения кода.
///
/// Отдельного маршрута нет намеренно: экран нужен ровно один раз, сразу
/// после верификации, и в истории навигации ему делать нечего.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();

  // Пусто, пока гость сам не выберет: «первый по алфавиту» по умолчанию —
  // верный способ отправить заказ в чужой отель.
  String _hotel = '';
  DateTime? _dob;

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty &&
      _hotel.isNotEmpty &&
      _roomController.text.trim().isNotEmpty;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      locale: Localizations.localeOf(context),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    await context.read<AuthController>().register(
      name: _nameController.text.trim(),
      hotelName: _hotel,
      roomNumber: _roomController.text.trim(),
      dob: _dob,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loading = context.watch<AuthController>().state.isLoading;
    final dateFormat = DateFormat(
      'd MMMM yyyy',
      Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text(
              l10n.authRegisterTitle,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: l10n.authName),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dob == null ? l10n.authDob : dateFormat.format(_dob!),
                        style: TextStyle(
                          fontSize: 15,
                          color: _dob == null
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            HotelDropdown(
              value: _hotel,
              label: l10n.authHotel,
              onChanged: (value) => setState(() => _hotel = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _roomController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(hintText: l10n.authRoom),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            const _HotelHint(),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _canContinue && !loading ? _submit : null,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.authContinue),
            ),
          ],
        ),
      ),
    );
  }
}

/// Выбор отеля. Вынесен отдельно — тем же списком пользуется профиль.
class HotelDropdown extends StatelessWidget {
  const HotelDropdown({
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return HotelPickerField(value: value, label: label, onChanged: onChanged);
  }
}

class _HotelHint extends StatelessWidget {
  const _HotelHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              // TODO l10n: ключа под эту подсказку в общем файле нет
              'Отель нужен, чтобы курьер знал, куда везти заказ',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
