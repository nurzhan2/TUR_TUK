import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/controller_state.dart';
import '../../controllers/locale_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/kemer_hotels.dart';
import '../auth/register_screen.dart' show HotelDropdown;

/// Профиль клиента: кто вошёл, куда везти заказ, на каком языке говорить.
///
/// Переключатель языка здесь — не настройка «на потом», а пункт показа:
/// заказчица спрашивает про три языка, и интерфейс обязан смениться в тот
/// же кадр, без перезапуска.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Профиль мог не успеть подтянуться на splash (или его сбросил выход),
    // а экран без шапки читается как поломка. Дёргаем один раз и только
    // если контроллер ещё ничего не грузил.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      if (auth.state == ControllerState.initial) auth.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = context.watch<AuthController>().profile;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (profile == null)
            const _SignInPrompt()
          else ...[
            _Header(name: profile.name, phone: profile.phone),
            const SizedBox(height: 8),
            _HotelCard(
              hotelName: profile.hotelName,
              roomNumber: profile.roomNumber,
              onEdit: () => _editHotel(profile.hotelName, profile.roomNumber),
            ),
          ],
          const SizedBox(height: 20),
          const _LanguageSwitch(),
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(l10n.profileMyOrders),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: () => context.go(AppRoutes.orders),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(l10n.profileSupport),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: () => context.push(AppRoutes.chat),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            // TODO l10n: ключа «О приложении» в общем файле нет
            title: const Text('О приложении'),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: _showAbout,
          ),
          if (profile != null)
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.accent),
              title: Text(
                l10n.profileLogout,
                style: const TextStyle(color: AppColors.accent),
              ),
              onTap: _logout,
            ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              // Версия зашита строкой: читать pubspec в рантайме нечем без
              // package_info_plus, а тянуть пакет ради подписи дороже.
              'TUR TUK · версия 1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await context.read<AuthController>().logout();
    if (mounted) context.go(AppRoutes.auth);
  }

  void _showAbout() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('TUR TUK'),
        content: const Text(
          // TODO l10n: текст «о приложении» ещё не согласован с заказчицей
          'Доставка сувениров, косметики и продуктов в отели Кемера.\n\n'
          'Версия 1.0.0',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  /// Правка отеля и комнаты. `register()` тем же вызовом обновляет профиль —
  /// отдельного метода «сохранить отель» в контракте контроллера нет, и
  /// заводить его ради одной формы значило бы править чужой файл.
  Future<void> _editHotel(String currentHotel, String currentRoom) async {
    final auth = context.read<AuthController>();
    final name = auth.profile?.name ?? '';
    final dob = auth.profile?.dob;

    final result = await showModalBottomSheet<_HotelEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _HotelSheet(hotel: resolveHotel(currentHotel), room: currentRoom),
    );
    if (result == null) return;

    await auth.register(
      name: name,
      hotelName: result.hotel,
      roomNumber: result.room,
      dob: dob,
    );
  }
}

/// Шапка вошедшего клиента: аватар из первой буквы имени, имя, телефон.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    // Пустое имя дало бы `substring(0, 1)` на пустой строке — берём заглушку.
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.gap,
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              letter.toUpperCase(),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Профиля нет — вместо шапки приглашение войти. Пустая шапка с прочерками
/// выглядит как сломанная загрузка.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Icon(
            Icons.person_outline,
            size: 56,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            // TODO l10n: ключа под это приглашение в общем файле нет
            'Войдите, чтобы видеть свои заказы и адрес доставки',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.auth),
            // TODO l10n: ключа «Войти» в общем файле нет
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }
}

/// Карточка «Мой отель» — то, ради чего профиль вообще открывают: курьер
/// везёт заказ по этим двум полям.
class _HotelCard extends StatelessWidget {
  const _HotelCard({
    required this.hotelName,
    required this.roomNumber,
    required this.onEdit,
  });

  final String hotelName;
  final String roomNumber;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.hotel_outlined, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileHotel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hotelName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.profileRoom,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roomNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onEdit, child: Text(l10n.profileEdit)),
          ],
        ),
      ),
    );
  }
}

/// Три сегмента в одном контейнере: активный — белая плашка с тенью.
///
/// Не выпадающий список: язык переключают на показе, он должен меняться
/// одним тапом, а все три варианта — быть видны сразу.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = context.watch<LocaleController>().locale.languageCode;

    const codes = ['ru', 'en', 'tr'];
    final labels = [
      l10n.profileRussian,
      l10n.profileEnglish,
      l10n.profileTurkish,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileLanguage,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
            ),
            child: Row(
              children: [
                for (var i = 0; i < codes.length; i++)
                  Expanded(
                    child: _Segment(
                      label: labels[i],
                      active: current == codes[i],
                      onTap: () => context.read<LocaleController>().setLocale(
                        Locale(codes[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Прозрачная подложка: без неё тап по промежутку между надписями
      // не доходит до обработчика, и сегмент кажется несработавшим.
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Результат правки отеля. Отдельный тип, а не пара строк: два поля одного
/// типа легко перепутать местами, и заказ уехал бы в комнату «Akra Kemer».
class _HotelEdit {
  const _HotelEdit(this.hotel, this.room);

  final String hotel;
  final String room;
}

class _HotelSheet extends StatefulWidget {
  const _HotelSheet({required this.hotel, required this.room});

  final String hotel;
  final String room;

  @override
  State<_HotelSheet> createState() => _HotelSheetState();
}

class _HotelSheetState extends State<_HotelSheet> {
  late String _hotel = widget.hotel;
  late final TextEditingController _room = TextEditingController(
    text: widget.room,
  );

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      // Клавиатура перекрывает кнопку «Сохранить», если не поднять лист
      // на её высоту.
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profileHotel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          HotelDropdown(
            value: _hotel,
            label: l10n.profileHotel,
            onChanged: (value) => setState(() => _hotel = value),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _room,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.profileRoom),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _room.text.trim().isEmpty
                ? null
                : () =>
                      Navigator.of(context)
                          .pop(_HotelEdit(_hotel, _room.text.trim())),
            child: Text(l10n.save),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
